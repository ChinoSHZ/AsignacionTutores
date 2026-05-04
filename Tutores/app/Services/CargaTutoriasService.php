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
                
                // 1. REQ 2: Ventana deslizante de semestres (Actual / Anterior)
                $semestreAnterior = Semestre::where('tipo', 'actual')->first();
                if ($semestreAnterior && $semestreAnterior->clave !== $claveSemestre) {
                    Semestre::avanzar($claveSemestre);
                } elseif (!$semestreAnterior) {
                    Semestre::create(['clave' => $claveSemestre, 'tipo' => 'actual']);
                }
                
                $semestreActual = Semestre::where('tipo', 'actual')->first();
                $semestreAnteriorInstancia = Semestre::where('tipo', 'anterior')->first();

                $alumnosProcesados = []; 
                $asignacionesHistoricasAnteriores = [];

                if ($semestreAnteriorInstancia) {
                    $viejas = DB::table('grupo_tutorado')
                        ->where('semestre_id', $semestreAnteriorInstancia->id)
                        ->get();
                    foreach($viejas as $v) {
                        $asignacionesHistoricasAnteriores[$v->tutorado_id] = $v->grupo_id;
                    }
                }

                $tutores = Profesor::all();
                $licenciaturas = Licenciatura::all();

                $lector = new class implements \Maatwebsite\Excel\Concerns\WithHeadingRow {
                    public function headingRow(): int { return 1; }
                };

                // Función auxiliar a prueba de balas para buscar tutor (Resuelve el problema del Excel desfasado)
                $buscarTutor = function($fila) use ($tutores) {
                    $val1 = $this->limpiar($fila['nombre_del_tutor'] ?? '');
                    $val2 = $this->limpiar($fila['apellido_paterno_tutor'] ?? '');
                    $val3 = $this->limpiar($fila['apellido_materno_tutor'] ?? '');

                    if (!$val1 && !$val2) return null;

                    return $tutores->first(function($p) use ($val1, $val2, $val3) {
                        $dbNom = $this->limpiar($p->nombre);
                        $dbPat = $this->limpiar($p->apellido_paterno);
                        
                        // Escenario 1: Normal (val1=Nombre, val2=Paterno)
                        if ($dbNom === $val1 && $dbPat === $val2) return true;
                        
                        // Escenario 2: Desplazado (val1=Paterno, val2=Materno, val3=Nombre) <- El caso de tu Excel
                        if ($dbNom === $val3 && $dbPat === $val1) return true;

                        // Escenario 3: Semi-desplazado (val1=Paterno, val2=Nombre)
                        if ($dbNom === $val2 && $dbPat === $val1) return true;

                        return false;
                    });
                };

                // 2. EXCEL HISTÓRICO
                $asignacionesNuevas = []; 
                if ($fileHistorico) {
                    $datos = Excel::toArray($lector, $fileHistorico)[0];
                    foreach ($datos as $fila) {
                        $cuenta = trim($fila['numero_de_cuenta'] ?? $fila['numero_cuenta'] ?? $fila['numerodecuenta'] ?? '');
                        if (!$cuenta) continue;

                        $licId = $licenciaturas->firstWhere('abreviatura', trim($fila['licenciatura'] ?? ''))?->id ?? 1;

                        $tutorado = Tutorado::updateOrCreate(
                            ['numero_cuenta' => $cuenta],
                            [
                                'nombre' => trim($fila['nombre_del_tutorado'] ?? ''),
                                'apellido_paterno' => trim($fila['apellido_paterno_tutorado'] ?? ''),
                                'apellido_materno' => trim($fila['apellido_materno_tutorado'] ?? null),
                                'periodo_ingreso' => trim($fila['periodo_ingreso'] ?? ''),
                                'licenciatura_id' => $licId,
                                'is_active' => true,
                            ]
                        );
                        $alumnosProcesados[] = $tutorado->id;

                        $prof = $buscarTutor($fila);
                        
                        if ($prof) {
                            $asignacionesNuevas[$cuenta] = clone $prof; 
                            $grupo = Grupo::firstOrCreate(['semestre_id' => $semestreActual->id, 'tutor_id' => $prof->id]);
                            
                            DB::table('grupo_tutorado')->updateOrInsert(
                                ['tutorado_id' => $tutorado->id, 'semestre_id' => $semestreActual->id],
                                ['grupo_id' => $grupo->id, 'estado_tutorado' => 'activo', 'movilidad' => 'no_cambiar', 'updated_at' => now()]
                            );
                        }
                    }
                }

                // 3. EXCEL NUEVOS INGRESOS
                if ($fileNuevos) {
                    $datos = Excel::toArray($lector, $fileNuevos)[0];
                    foreach ($datos as $fila) {
                        $cuenta = trim($fila['numero_de_cuenta'] ?? $fila['numero_cuenta'] ?? $fila['numerodecuenta'] ?? '');
                        if (!$cuenta) continue;

                        $licId = $licenciaturas->firstWhere('abreviatura', trim($fila['licenciatura_tutorado'] ?? ''))?->id ?? 1;
                        $tutoradoExiste = Tutorado::where('numero_cuenta', $cuenta)->exists();

                        $tutorado = Tutorado::updateOrCreate(
                            ['numero_cuenta' => $cuenta],
                            [
                                'nombre' => trim($fila['nombre_del_tutorado'] ?? ''),
                                'apellido_paterno' => trim($fila['apellido_paterno_tutorado'] ?? ''),
                                'apellido_materno' => trim($fila['apellido_materno_tutorado'] ?? null),
                                'periodo_ingreso' => trim($fila['semestre_ingreso'] ?? $fila['periodo_ingreso'] ?? ''),
                                'licenciatura_id' => $licId,
                                'is_active' => true,
                            ]
                        );
                        $alumnosProcesados[] = $tutorado->id;

                        if (!isset($asignacionesNuevas[$cuenta])) {
                            $prof = $buscarTutor($fila);
                            
                            if ($prof) {
                                $grupo = Grupo::firstOrCreate(['semestre_id' => $semestreActual->id, 'tutor_id' => $prof->id]);
                                $movilidad = $tutoradoExiste ? 'no_cambiar' : 'nuevo_ingreso';

                                DB::table('grupo_tutorado')->updateOrInsert(
                                    ['tutorado_id' => $tutorado->id, 'semestre_id' => $semestreActual->id],
                                    ['grupo_id' => $grupo->id, 'estado_tutorado' => 'activo', 'movilidad' => $movilidad, 'updated_at' => now()]
                                );
                            }
                        }
                    }
                }

                // 4. EXCEL PROPUESTA SEMESTRE
                if ($filePropuesta) {
                    $datos = Excel::toArray($lector, $filePropuesta)[0];
                    foreach ($datos as $fila) {
                        $cuenta = trim($fila['numero_de_cuenta'] ?? $fila['numero_cuenta'] ?? $fila['numerodecuenta'] ?? '');
                        if (!$cuenta) continue;

                        $tutorado = Tutorado::where('numero_cuenta', $cuenta)->first();
                        if (!$tutorado) continue; 

                        $alumnosProcesados[] = $tutorado->id;
                        $tutorado->update(['is_active' => true]); 

                        $prof = $buscarTutor($fila);
                        
                        if ($prof) {
                            $grupoNuevo = Grupo::firstOrCreate(['semestre_id' => $semestreActual->id, 'tutor_id' => $prof->id]);

                            $movilidad = 'no_cambiar';
                            $estadoExcelKey = isset($fila['estado_cambiar_no_cambiar']) ? 'estado_cambiar_no_cambiar' : 'estado';
                            $estadoExcel = strtoupper(trim($fila[$estadoExcelKey] ?? ''));

                            if (isset($asignacionesHistoricasAnteriores[$tutorado->id])) {
                                $grupoAntId = $asignacionesHistoricasAnteriores[$tutorado->id];
                                $grupoAnt = Grupo::find($grupoAntId);
                                if ($grupoAnt && $grupoAnt->tutor_id !== $prof->id) {
                                    $movilidad = 'cambiar'; 
                                }
                            } else {
                                if (str_contains($estadoExcel, 'CAMBIAR') && !str_contains($estadoExcel, 'NO')) {
                                    $movilidad = 'cambiar';
                                }
                            }

                            DB::table('grupo_tutorado')->updateOrInsert(
                                ['tutorado_id' => $tutorado->id, 'semestre_id' => $semestreActual->id],
                                ['grupo_id' => $grupoNuevo->id, 'estado_tutorado' => 'activo', 'movilidad' => $movilidad, 'updated_at' => now()]
                            );
                        }
                    }
                }

                $alumnosProcesados = array_unique($alumnosProcesados);
                Tutorado::whereNotIn('id', $alumnosProcesados)->update(['is_active' => false]);
                
                if ($semestreAnteriorInstancia) {
                    $asignacionesViejas = DB::table('grupo_tutorado')
                        ->where('semestre_id', $semestreAnteriorInstancia->id)
                        ->whereNotIn('tutorado_id', $alumnosProcesados)
                        ->get();

                    foreach($asignacionesViejas as $asig) {
                        $grupoViejo = Grupo::find($asig->grupo_id);
                        if ($grupoViejo) {
                            $grupoNuevo = Grupo::firstOrCreate([
                                'semestre_id' => $semestreActual->id,
                                'tutor_id' => $grupoViejo->tutor_id
                            ]);
                            DB::table('grupo_tutorado')->updateOrInsert(
                                ['tutorado_id' => $asig->tutorado_id, 'semestre_id' => $semestreActual->id],
                                ['grupo_id' => $grupoNuevo->id, 'estado_tutorado' => 'baja', 'movilidad' => 'no_cambiar', 'updated_at' => now()]
                            );
                        }
                    }
                }

                // ===================================================================================
                // 5. ALGORITMO FINAL DE DISTRIBUCIÓN POR CARRERA
                // ===================================================================================

                $licenciaturasTotales = Licenciatura::all();

                foreach ($licenciaturasTotales as $lic) {
                    // a) Contabilizar Tutores Activos en la carrera
                    $tutoresActivos = Profesor::where('estado', 'Activo')
                        ->whereHas('licenciaturas', function ($query) use ($lic) {
                            $query->where('licenciaturas.id', $lic->id);
                        })->get();

                    $totalTutores = $tutoresActivos->count();
                    if ($totalTutores === 0) continue; 

                    // b) Contabilizar Alumnos Activos en la carrera
                    $alumnosActivos = Tutorado::where('licenciatura_id', $lic->id)
                        ->where('is_active', true)
                        ->get();

                    $totalAlumnos = $alumnosActivos->count();
                    if ($totalAlumnos === 0) continue;

                    // c) Cálculo de Alumnos por Tutor
                    $metaPorTutor = (int) round($totalAlumnos / $totalTutores);

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

                    // d) Fase 1: Preservar "No Cambiar"
                    $alumnosFijos = DB::table('grupo_tutorado')
                        ->where('semestre_id', $semestreActual->id)
                        ->where('estado_tutorado', 'activo')
                        ->where('movilidad', 'no_cambiar')
                        ->whereIn('grupo_id', $gruposDeLicenciatura)
                        ->get();

                    foreach ($alumnosFijos as $fijo) {
                        if (isset($capacidadTutores[$fijo->grupo_id])) {
                            $capacidadTutores[$fijo->grupo_id]++;
                        }
                    }

                    // Extraer los alumnos que se pueden mover (cambiar o nuevo_ingreso)
                    $alumnosParaMover = DB::table('grupo_tutorado')
                        ->where('semestre_id', $semestreActual->id)
                        ->where('estado_tutorado', 'activo')
                        ->whereIn('movilidad', ['cambiar', 'nuevo_ingreso'])
                        ->whereIn('tutorado_id', $alumnosActivos->pluck('id'))
                        ->pluck('tutorado_id')
                        ->toArray();

                    shuffle($alumnosParaMover);

                    // e) Fase 2: Balanceo
                    foreach ($alumnosParaMover as $tutoradoId) {
                        $gruposDisponibles = array_filter($capacidadTutores, function($count) use ($metaPorTutor) {
                            return $count < $metaPorTutor;
                        });

                        if (empty($gruposDisponibles)) {
                            $gruposDisponibles = $capacidadTutores;
                        }

                        asort($gruposDisponibles);
                        
                        $grupoSeleccionadoId = array_key_first($gruposDisponibles);

                        DB::table('grupo_tutorado')
                            ->where('tutorado_id', $tutoradoId)
                            ->where('semestre_id', $semestreActual->id)
                            ->update(['grupo_id' => $grupoSeleccionadoId]);

                        $capacidadTutores[$grupoSeleccionadoId]++;
                    }
                }
                
            });

            return ['success' => true, 'message' => 'Carga de datos completada correctamente.'];
        } catch (\Throwable $e) {
            return ['success' => false, 'error' => 'Error backend: ' . $e->getMessage() . ' Linea: ' . $e->getLine()];
        }
    }
}