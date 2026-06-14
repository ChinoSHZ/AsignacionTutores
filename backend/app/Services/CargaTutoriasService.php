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
            // Desactivar restricciones y sincronización estricta temporalmente para acelerar SQLite
            DB::statement('PRAGMA foreign_keys = OFF;');
            DB::statement('PRAGMA synchronous = OFF;');

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
                
                // Caché en memoria para evitar consultas redundantes y bloqueos
                $licenciaturasDict = $licenciaturas->keyBy('abreviatura');
                $gruposCache = []; 
                $pivotBatch = []; // Acumulador para inserciones masivas en grupo_tutorado

                $lector = new class implements \Maatwebsite\Excel\Concerns\WithHeadingRow {
                    public function headingRow(): int { return 1; }
                };

                $buscarTutor = function($fila) use ($tutores) {
                    $val1 = $this->limpiar($fila['nombre_del_tutor'] ?? '');
                    $val2 = $this->limpiar($fila['apellido_paterno_tutor'] ?? '');
                    $val3 = $this->limpiar($fila['apellido_materno_tutor'] ?? '');

                    if (!$val1 && !$val2) return null;

                    return $tutores->first(function($p) use ($val1, $val2, $val3) {
                        $dbNom = $this->limpiar($p->nombre);
                        $dbPat = $this->limpiar($p->apellido_paterno);
                        
                        if ($dbNom === $val1 && $dbPat === $val2) return true;
                        if ($dbNom === $val3 && $dbPat === $val1) return true;
                        if ($dbNom === $val2 && $dbPat === $val1) return true;

                        return false;
                    });
                };

                // Función auxiliar para registrar en el batch en lugar de insertar 1 a 1
                $registrarPivot = function($tutoradoId, $grupoId, $estado, $movilidad) use (&$pivotBatch, $semestreActual) {
                    $pivotBatch[$tutoradoId] = [
                        'tutorado_id' => $tutoradoId,
                        'semestre_id' => $semestreActual->id,
                        'grupo_id' => $grupoId,
                        'estado_tutorado' => $estado,
                        'movilidad' => $movilidad,
                        'created_at' => now()->toDateTimeString(),
                        'updated_at' => now()->toDateTimeString(),
                    ];
                };

                // 2. EXCEL HISTÓRICO
                $asignacionesNuevas = []; 
                if ($fileHistorico) {
                    $datos = Excel::toArray($lector, $fileHistorico)[0];
                    foreach ($datos as $fila) {
                        $cuenta = trim($fila['numero_de_cuenta'] ?? $fila['numero_cuenta'] ?? $fila['numerodecuenta'] ?? '');
                        if (!$cuenta) continue;

                        $abreviatura = trim($fila['licenciatura'] ?? '');
                        $licId = isset($licenciaturasDict[$abreviatura]) ? $licenciaturasDict[$abreviatura]->id : 1;

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
                            
                            if (!isset($gruposCache[$prof->id])) {
                                $grupo = Grupo::firstOrCreate(['semestre_id' => $semestreActual->id, 'tutor_id' => $prof->id]);
                                $gruposCache[$prof->id] = $grupo->id;
                            }
                            
                            $registrarPivot($tutorado->id, $gruposCache[$prof->id], 'activo', 'no_cambiar');
                        }
                    }
                }

                // 3. EXCEL NUEVOS INGRESOS
                if ($fileNuevos) {
                    $datos = Excel::toArray($lector, $fileNuevos)[0];
                    foreach ($datos as $fila) {
                        $cuenta = trim($fila['numero_de_cuenta'] ?? $fila['numero_cuenta'] ?? $fila['numerodecuenta'] ?? '');
                        if (!$cuenta) continue;

                        $abreviatura = trim($fila['licenciatura_tutorado'] ?? '');
                        $licId = isset($licenciaturasDict[$abreviatura]) ? $licenciaturasDict[$abreviatura]->id : 1;
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
                                if (!isset($gruposCache[$prof->id])) {
                                    $grupo = Grupo::firstOrCreate(['semestre_id' => $semestreActual->id, 'tutor_id' => $prof->id]);
                                    $gruposCache[$prof->id] = $grupo->id;
                                }
                                
                                $movilidad = $tutoradoExiste ? 'no_cambiar' : 'nuevo_ingreso';
                                $registrarPivot($tutorado->id, $gruposCache[$prof->id], 'activo', $movilidad);
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
                            if (!isset($gruposCache[$prof->id])) {
                                $grupo = Grupo::firstOrCreate(['semestre_id' => $semestreActual->id, 'tutor_id' => $prof->id]);
                                $gruposCache[$prof->id] = $grupo->id;
                            }

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

                            $registrarPivot($tutorado->id, $gruposCache[$prof->id], 'activo', $movilidad);
                        }
                    }
                }

                // Inserción masiva segmentada (Evita el límite de variables de SQLite)
                $chunks = array_chunk(array_values($pivotBatch), 500);
                foreach ($chunks as $chunk) {
                    DB::table('grupo_tutorado')->upsert(
                        $chunk, 
                        ['tutorado_id', 'semestre_id'], 
                        ['grupo_id', 'estado_tutorado', 'movilidad', 'updated_at']
                    );
                }

                $alumnosProcesados = array_unique($alumnosProcesados);
                
                // Desactivar inactivos procesando en lotes para evitar error de >999 variables
                $todosTutoradosIds = Tutorado::pluck('id')->toArray();
                $idsParaDesactivar = array_diff($todosTutoradosIds, $alumnosProcesados);
                
                foreach (array_chunk($idsParaDesactivar, 500) as $chunkIds) {
                    Tutorado::whereIn('id', $chunkIds)->update(['is_active' => false]);
                }
                
                if ($semestreAnteriorInstancia) {
                    // Filtrar en memoria para no exceder límites de parámetros SQL
                    $asignacionesViejas = DB::table('grupo_tutorado')
                        ->where('semestre_id', $semestreAnteriorInstancia->id)
                        ->get()
                        ->filter(function($asig) use ($alumnosProcesados) {
                            return !in_array($asig->tutorado_id, $alumnosProcesados);
                        });

                    $bajasBatch = [];
                    foreach($asignacionesViejas as $asig) {
                        $grupoViejo = Grupo::find($asig->grupo_id);
                        if ($grupoViejo) {
                            if (!isset($gruposCache[$grupoViejo->tutor_id])) {
                                $grupoNuevo = Grupo::firstOrCreate([
                                    'semestre_id' => $semestreActual->id,
                                    'tutor_id' => $grupoViejo->tutor_id
                                ]);
                                $gruposCache[$grupoViejo->tutor_id] = $grupoNuevo->id;
                            }
                            
                            $bajasBatch[] = [
                                'tutorado_id' => $asig->tutorado_id,
                                'semestre_id' => $semestreActual->id,
                                'grupo_id' => $gruposCache[$grupoViejo->tutor_id],
                                'estado_tutorado' => 'baja',
                                'movilidad' => 'no_cambiar',
                                'created_at' => now()->toDateTimeString(),
                                'updated_at' => now()->toDateTimeString(),
                            ];
                        }
                    }

                    foreach (array_chunk($bajasBatch, 500) as $chunk) {
                        DB::table('grupo_tutorado')->upsert(
                            $chunk, 
                            ['tutorado_id', 'semestre_id'], 
                            ['grupo_id', 'estado_tutorado', 'movilidad', 'updated_at']
                        );
                    }
                }

                // ===================================================================================
                // 5. ALGORITMO FINAL DE DISTRIBUCIÓN POR CARRERA
                // ===================================================================================

                $licenciaturasTotales = Licenciatura::all();

                foreach ($licenciaturasTotales as $lic) {
                    $tutoresActivos = Profesor::where('estado', 'Activo')
                        ->whereHas('licenciaturas', function ($query) use ($lic) {
                            $query->where('licenciaturas.id', $lic->id);
                        })->get();

                    $totalTutores = $tutoresActivos->count();
                    if ($totalTutores === 0) continue; 

                    $alumnosActivos = Tutorado::where('licenciatura_id', $lic->id)
                        ->where('is_active', true)
                        ->get();

                    $totalAlumnos = $alumnosActivos->count();
                    if ($totalAlumnos === 0) continue;

                    $metaPorTutor = (int) round($totalAlumnos / $totalTutores);

                    $capacidadTutores = [];
                    $gruposDeLicenciatura = [];

                    foreach ($tutoresActivos as $tutor) {
                        if (!isset($gruposCache[$tutor->id])) {
                            $grupo = Grupo::firstOrCreate([
                                'semestre_id' => $semestreActual->id,
                                'tutor_id' => $tutor->id
                            ]);
                            $gruposCache[$tutor->id] = $grupo->id;
                        }
                        $gruposDeLicenciatura[] = $gruposCache[$tutor->id];
                        $capacidadTutores[$gruposCache[$tutor->id]] = 0; 
                    }

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

                    // Filtrado en memoria para evitar colapso de variable SQLite
                    $alumnosActivosIds = $alumnosActivos->pluck('id')->toArray();
                    $alumnosParaMover = DB::table('grupo_tutorado')
                        ->where('semestre_id', $semestreActual->id)
                        ->where('estado_tutorado', 'activo')
                        ->whereIn('movilidad', ['cambiar', 'nuevo_ingreso'])
                        ->get()
                        ->filter(function($pivot) use ($alumnosActivosIds) {
                            return in_array($pivot->tutorado_id, $alumnosActivosIds);
                        })
                        ->pluck('tutorado_id')
                        ->toArray();

                    shuffle($alumnosParaMover);

                    $updatesBatch = [];
                    foreach ($alumnosParaMover as $tutoradoId) {
                        $gruposDisponibles = array_filter($capacidadTutores, function($count) use ($metaPorTutor) {
                            return $count < $metaPorTutor;
                        });

                        if (empty($gruposDisponibles)) {
                            $gruposDisponibles = $capacidadTutores;
                        }

                        asort($gruposDisponibles);
                        
                        $grupoSeleccionadoId = array_key_first($gruposDisponibles);

                        $updatesBatch[] = [
                            'tutorado_id' => $tutoradoId,
                            'semestre_id' => $semestreActual->id,
                            'grupo_id' => $grupoSeleccionadoId,
                            'estado_tutorado' => 'activo',
                            'movilidad' => 'cambiar',
                            'updated_at' => now()->toDateTimeString(),
                        ];

                        $capacidadTutores[$grupoSeleccionadoId]++;
                    }

                    foreach (array_chunk($updatesBatch, 500) as $chunk) {
                        DB::table('grupo_tutorado')->upsert(
                            $chunk, 
                            ['tutorado_id', 'semestre_id'], 
                            ['grupo_id', 'updated_at']
                        );
                    }
                }
                
            });

            DB::statement('PRAGMA foreign_keys = ON;');
            DB::statement('PRAGMA synchronous = NORMAL;');

            return ['success' => true, 'message' => 'Carga de datos completada correctamente.'];
        } catch (\Throwable $e) {
            DB::statement('PRAGMA foreign_keys = ON;');
            DB::statement('PRAGMA synchronous = NORMAL;');
            return ['success' => false, 'error' => 'Error backend: ' . $e->getMessage() . ' Linea: ' . $e->getLine()];
        }
    }
}