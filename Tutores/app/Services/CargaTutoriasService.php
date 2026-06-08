<?php

namespace App\Services;

use App\Models\Semestre;
use App\Models\Tutorado;
use App\Models\Profesor;
use App\Models\Grupo;
use App\Models\Licenciatura;
use Illuminate\Support\Facades\DB;
use Maatwebsite\Excel\Facades\Excel;

class CargaTutoriasService
{
    private function limpiar($texto) {
        if (!$texto) return '';
        $busqueda  = ['á','é','í','ó','ú','Á','É','Í','Ó','Ú','ñ','Ñ'];
        $reemplazo = ['a','e','i','o','u','A','E','I','O','U','n','N'];
        $texto = str_replace($busqueda, $reemplazo, $texto);
        return strtoupper(preg_replace('/\s+/', '', $texto));
    }

    public function procesarCargaMasiva($fileNuevos, $fileHistorico, $filePropuesta, $claveSemestre)
    {
        try {
            DB::transaction(function () use ($fileNuevos, $fileHistorico, $filePropuesta, $claveSemestre) {
                
                // 1. Ventana deslizante de semestres
                $semestreAnterior = Semestre::where('tipo', 'actual')->first();
                if ($semestreAnterior && $semestreAnterior->clave !== $claveSemestre) {
                    Semestre::avanzar($claveSemestre);
                } elseif (!$semestreAnterior) {
                    Semestre::create(['clave' => $claveSemestre, 'tipo' => 'actual']);
                }
                
                $semestreActual = Semestre::where('tipo', 'actual')->first();
                
                $tutores = Profesor::all();
                $licenciaturas = Licenciatura::all();
                
                $sinLicId = Licenciatura::firstOrCreate(
                    ['abreviatura' => 'S/L'], 
                    ['codigo' => 'C00', 'nombre' => 'Sin licenciatura']
                )->id;

                $lector = new class implements \Maatwebsite\Excel\Concerns\WithHeadingRow {
                    public function headingRow(): int { return 1; }
                };

                // Función de coincidencia estricta para apellidos compuestos
                $buscarTutor = function($apPaterno, $apMaterno, $nombre) use ($tutores) {
                    $valPat = $this->limpiar($apPaterno);
                    $valMat = $this->limpiar($apMaterno);
                    $valNom = $this->limpiar($nombre);

                    if (!$valNom && !$valPat) return null;

                    return $tutores->first(function($p) use ($valPat, $valMat, $valNom) {
                        $dbNom = $this->limpiar($p->nombre);
                        $dbPat = $this->limpiar($p->apellido_paterno);
                        $dbMat = $this->limpiar($p->apellido_materno);
                        
                        if ($dbNom === $valNom && $dbPat === $valPat && $dbMat === $valMat) return true;
                        if ($dbNom === $valNom && $dbPat === $valPat) return true;

                        return false;
                    });
                };

                $alumnosProcesados = [];
                $asignacionesRealizadas = []; // Control de prioridad

                // =========================================================
                // FASE 1: PROPUESTA SEMESTRE (Asignación directa + 'no_cambiar')
                // =========================================================
                if ($filePropuesta) {
                    $datos = Excel::toArray($lector, $filePropuesta)[0];
                    foreach ($datos as $fila) {
                        $cuenta = trim($fila['numero_de_cuenta'] ?? $fila['numero_cuenta'] ?? '');
                        if (!$cuenta) continue;

                        $tutorado = Tutorado::where('numero_cuenta', $cuenta)->first();
                        
                        // Respetar nombres completos (apellidos compuestos)
                        if (!$tutorado) {
                            $tutorado = Tutorado::create([
                                'numero_cuenta' => $cuenta,
                                'nombre' => trim($fila['nombre_del_tutorado'] ?? ''),
                                'apellido_paterno' => trim($fila['apellido_paterno_tutorado'] ?? ''),
                                'apellido_materno' => trim($fila['apellido_materno_tutorado'] ?? ''),
                                'periodo_ingreso' => 'N/A',
                                'licenciatura_id' => $sinLicId,
                                'is_active' => true,
                            ]);
                        } else {
                            $tutorado->update([
                                'nombre' => trim($fila['nombre_del_tutorado'] ?? $tutorado->nombre),
                                'apellido_paterno' => trim($fila['apellido_paterno_tutorado'] ?? $tutorado->apellido_paterno),
                                'apellido_materno' => trim($fila['apellido_materno_tutorado'] ?? $tutorado->apellido_materno),
                                'is_active' => true,
                            ]);
                        }

                        $alumnosProcesados[] = $tutorado->id;
                        $asignacionesRealizadas[$cuenta] = true;

                        $prof = $buscarTutor($fila['apellido_paterno_tutor'] ?? '', $fila['apellido_materno_tutor'] ?? '', $fila['nombre_del_tutor'] ?? '');
                        
                        if ($prof) {
                            $grupo = Grupo::firstOrCreate(['semestre_id' => $semestreActual->id, 'tutor_id' => $prof->id]);
                            
                            DB::table('grupo_tutorado')->updateOrInsert(
                                ['tutorado_id' => $tutorado->id, 'semestre_id' => $semestreActual->id],
                                ['grupo_id' => $grupo->id, 'estado_tutorado' => 'activo', 'movilidad' => 'no_cambiar', 'updated_at' => now()]
                            );
                        }
                    }
                }

                // =========================================================
                // FASE 2: REGISTRO HISTÓRICO (Asignación directa + 'cambiar')
                // =========================================================
                if ($fileHistorico) {
                    $datos = Excel::toArray($lector, $fileHistorico)[0];
                    foreach ($datos as $fila) {
                        $cuenta = trim($fila['numero_de_cuenta'] ?? $fila['numero_cuenta'] ?? '');
                        if (!$cuenta) continue;

                        $licId = $licenciaturas->firstWhere('abreviatura', trim($fila['licenciatura'] ?? ''))?->id ?? $sinLicId;

                        $tutorado = Tutorado::updateOrCreate(
                            ['numero_cuenta' => $cuenta],
                            [
                                'nombre' => trim($fila['nombre_del_tutorado'] ?? ''),
                                'apellido_paterno' => trim($fila['apellido_paterno_tutorado'] ?? ''),
                                'apellido_materno' => trim($fila['apellido_materno_tutorado'] ?? ''),
                                'periodo_ingreso' => trim($fila['periodo_ingreso'] ?? ''),
                                'licenciatura_id' => $licId,
                                'is_active' => true,
                            ]
                        );
                        
                        $alumnosProcesados[] = $tutorado->id;

                        if (isset($asignacionesRealizadas[$cuenta])) continue;
                        $asignacionesRealizadas[$cuenta] = true;

                        $prof = $buscarTutor($fila['apellido_paterno_tutor'] ?? '', $fila['apellido_materno_tutor'] ?? '', $fila['nombre_del_tutor'] ?? '');
                        
                        if ($prof) {
                            $grupo = Grupo::firstOrCreate(['semestre_id' => $semestreActual->id, 'tutor_id' => $prof->id]);
                            
                            DB::table('grupo_tutorado')->updateOrInsert(
                                ['tutorado_id' => $tutorado->id, 'semestre_id' => $semestreActual->id],
                                ['grupo_id' => $grupo->id, 'estado_tutorado' => 'activo', 'movilidad' => 'cambiar', 'updated_at' => now()]
                            );
                        }
                    }
                }

                // =========================================================
                // FASE 3: NUEVO INGRESO (Extracción y 'nuevo_ingreso')
                // =========================================================
                $nuevosIngresosIds = [];
                if ($fileNuevos) {
                    $datos = Excel::toArray($lector, $fileNuevos)[0];
                    foreach ($datos as $fila) {
                        $cuenta = trim($fila['numero_de_cuenta'] ?? $fila['numero_cuenta'] ?? '');
                        if (!$cuenta) continue;

                        $licId = $licenciaturas->firstWhere('abreviatura', trim($fila['licenciatura_tutorado'] ?? ''))?->id ?? $sinLicId;

                        $tutorado = Tutorado::updateOrCreate(
                            ['numero_cuenta' => $cuenta],
                            [
                                'nombre' => trim($fila['nombre_del_tutorado'] ?? ''),
                                'apellido_paterno' => trim($fila['apellido_paterno_tutorado'] ?? ''),
                                'apellido_materno' => trim($fila['apellido_materno_tutorado'] ?? ''),
                                'periodo_ingreso' => trim($fila['semestre_ingreso'] ?? ''),
                                'licenciatura_id' => $licId,
                                'is_active' => true,
                            ]
                        );
                        
                        $alumnosProcesados[] = $tutorado->id;

                        if (isset($asignacionesRealizadas[$cuenta])) continue;
                        $asignacionesRealizadas[$cuenta] = true;
                        
                        $nuevosIngresosIds[] = $tutorado->id; 
                    }
                }

                $alumnosProcesados = array_unique($alumnosProcesados);
                Tutorado::whereNotIn('id', $alumnosProcesados)->update(['is_active' => false]);
                
                // ===================================================================================
                // FASE 4: ALGORITMO FINAL DE DISTRIBUCIÓN Y BALANCEO
                // ===================================================================================

                foreach (Licenciatura::all() as $lic) {
                    $tutoresActivos = Profesor::where('estado', 'Activo')
                        ->whereHas('licenciaturas', function ($query) use ($lic) {
                            $query->where('licenciaturas.id', $lic->id);
                        })->get();

                    if ($tutoresActivos->count() === 0) continue; 

                    $alumnosActivosLic = Tutorado::where('licenciatura_id', $lic->id)
                        ->where('is_active', true)
                        ->get();

                    if ($alumnosActivosLic->count() === 0) continue;

                    $capacidadTutores = [];
                    $gruposDeLicenciatura = [];

                    foreach ($tutoresActivos as $tutor) {
                        $grupo = Grupo::firstOrCreate([
                            'semestre_id' => $semestreActual->id,
                            'tutor_id' => $tutor->id
                        ]);
                        $gruposDeLicenciatura[] = $grupo->id;
                        $capacidadTutores[$grupo->id] = 0; 
                    }

                    $asignacionesActuales = DB::table('grupo_tutorado')
                        ->where('semestre_id', $semestreActual->id)
                        ->where('estado_tutorado', 'activo')
                        ->whereIn('grupo_id', $gruposDeLicenciatura)
                        ->get();
                        
                    foreach ($asignacionesActuales as $asig) {
                        if (isset($capacidadTutores[$asig->grupo_id])) {
                            $capacidadTutores[$asig->grupo_id]++;
                        }
                    }

                    // A. Asignación equitativa de Nuevo Ingreso
                    $nuevosLic = $alumnosActivosLic->whereIn('id', $nuevosIngresosIds)->pluck('id')->toArray();
                    shuffle($nuevosLic);

                    foreach ($nuevosLic as $tutoradoId) {
                        asort($capacidadTutores);
                        $grupoMinId = array_key_first($capacidadTutores);
                        
                        DB::table('grupo_tutorado')->updateOrInsert(
                            ['tutorado_id' => $tutoradoId, 'semestre_id' => $semestreActual->id],
                            ['grupo_id' => $grupoMinId, 'estado_tutorado' => 'activo', 'movilidad' => 'nuevo_ingreso', 'updated_at' => now()]
                        );
                        $capacidadTutores[$grupoMinId]++;
                    }

                    // B. Ciclo de Balanceo Recursivo
                    $lockedGroups = []; 

                    while (true) {
                        asort($capacidadTutores);
                        $minGroupId = array_key_first($capacidadTutores);
                        $minCount = $capacidadTutores[$minGroupId];
                        
                        $maxGroupId = null;
                        $maxCount = -1;
                        
                        arsort($capacidadTutores);
                        foreach ($capacidadTutores as $gId => $c) {
                            if (!in_array($gId, $lockedGroups)) {
                                $maxGroupId = $gId;
                                $maxCount = $c;
                                break; 
                            }
                        }

                        if ($maxGroupId === null || ($maxCount - $minCount) <= 1) {
                            break;
                        }

                        // Prioridad de extracción: 1º 'cambiar' -> 2º 'nuevo_ingreso'. Omite 'no_cambiar'.
                        $candidato = DB::table('grupo_tutorado')
                            ->where('grupo_id', $maxGroupId)
                            ->where('semestre_id', $semestreActual->id)
                            ->where('estado_tutorado', 'activo')
                            ->whereIn('movilidad', ['cambiar', 'nuevo_ingreso'])
                            ->orderByRaw("FIELD(movilidad, 'cambiar', 'nuevo_ingreso')")
                            ->first();

                        if ($candidato) {
                            DB::table('grupo_tutorado')
                                ->where('id', $candidato->id)
                                ->update(['grupo_id' => $minGroupId]);
                            
                            $capacidadTutores[$maxGroupId]--;
                            $capacidadTutores[$minGroupId]++;
                        } else {
                            $lockedGroups[] = $maxGroupId;
                        }
                    }
                }
                
            });

            return ['success' => true, 'message' => 'Carga de datos completada correctamente.'];
        } catch (\Throwable $e) {
            return ['success' => false, 'error' => 'Error backend: ' . $e->getMessage() . ' Linea: ' . $e->getLine()];
        }
    }
}