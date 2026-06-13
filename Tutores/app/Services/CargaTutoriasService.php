<?php

namespace App\Services;

use App\Models\Semestre;
use App\Models\Tutorado;
use App\Models\Profesor;
use App\Models\Grupo;
use App\Models\Licenciatura;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Crypt;
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

    private function extraerCuenta($fila) {
        foreach ($fila as $k => $v) {
            $val = preg_replace('/\.0+$/', '', (string)$v);
            $val = preg_replace('/[^0-9]/', '', $val);
            if (strlen($val) === 7) return $val; 
        }
        foreach ($fila as $k => $v) {
            $kl = strtolower(trim($k));
            if (str_contains($kl, 'cuenta') || str_contains($kl, 'n_mero') || str_contains($kl, 'numero')) {
                $val = preg_replace('/\.0+$/', '', (string)$v);
                $val = preg_replace('/[^0-9A-Za-z]/', '', $val);
                if (!empty($val)) return $val;
            }
        }
        return '';
    }

    private function extraerNombresTutorado($fila) {
        $n = trim($fila['nombre_del_tutorado'] ?? $fila['nombre'] ?? '');
        $p = trim($fila['apellido_paterno_tutorado'] ?? $fila['apellido_paterno'] ?? '');
        $m = trim($fila['apellido_materno_tutorado'] ?? $fila['apellido_materno'] ?? '');
        
        if (!$n) {
            foreach ($fila as $k => $v) {
                $kl = str_replace('_', '', strtolower(trim($k)));
                if (str_contains($kl, 'nombre') && !str_contains($kl, 'deltutor') && !str_ends_with($kl, 'tutor')) $n = trim((string)$v);
            }
        }
        if (!$p) {
            foreach ($fila as $k => $v) {
                $kl = str_replace('_', '', strtolower(trim($k)));
                if (str_contains($kl, 'paterno') && !str_contains($kl, 'deltutor') && !str_ends_with($kl, 'tutor')) $p = trim((string)$v);
            }
        }
        if (!$m) {
            foreach ($fila as $k => $v) {
                $kl = str_replace('_', '', strtolower(trim($k)));
                if (str_contains($kl, 'materno') && !str_contains($kl, 'deltutor') && !str_ends_with($kl, 'tutor')) $m = trim((string)$v);
            }
        }
        return [$n, $p, $m];
    }

    private function extraerNombresTutor($fila) {
        $n = trim($fila['nombre_del_tutor'] ?? '');
        $p = trim($fila['apellido_paterno_tutor'] ?? '');
        $m = trim($fila['apellido_materno_tutor'] ?? '');
        
        if (!$n) {
            foreach ($fila as $k => $v) {
                $kl = str_replace('_', '', strtolower(trim($k)));
                if (str_contains($kl, 'nombre') && str_contains($kl, 'tutor') && !str_contains($kl, 'tutorado')) $n = trim((string)$v);
            }
        }
        if (!$p) {
            foreach ($fila as $k => $v) {
                $kl = str_replace('_', '', strtolower(trim($k)));
                if (str_contains($kl, 'paterno') && str_contains($kl, 'tutor') && !str_contains($kl, 'tutorado')) $p = trim((string)$v);
            }
        }
        if (!$m) {
            foreach ($fila as $k => $v) {
                $kl = str_replace('_', '', strtolower(trim($k)));
                if (str_contains($kl, 'materno') && str_contains($kl, 'tutor') && !str_contains($kl, 'tutorado')) $m = trim((string)$v);
            }
        }
        return [$n, $p, $m];
    }

    private function extraerLic($fila) {
        $raw = trim($fila['licenciatura_tutorado'] ?? $fila['licenciatura_tutor'] ?? $fila['licenciatura'] ?? $fila['carrera'] ?? '');
        if (!$raw) {
            foreach ($fila as $k => $v) {
                $kl = strtolower(trim($k));
                if (str_contains($kl, 'licenciatura') || str_contains($kl, 'carrera')) return trim((string)$v);
            }
        }
        return $raw;
    }

    private function extraerEstadoPropuesta($fila) {
        foreach ($fila as $k => $v) {
            $kl = str_replace('_', '', strtolower(trim($k)));
            if (str_contains($kl, 'estado') || str_contains($kl, 'cambiar')) {
                return strtoupper(trim((string)$v));
            }
        }
        return '';
    }

    public function procesarCargaMasiva($fileNuevos, $fileHistorico, $filePropuesta, $claveSemestre)
    {
        ini_set('max_execution_time', '0');
        ini_set('memory_limit', '-1');
        DB::connection()->disableQueryLog();

        try {
            $lector = new class implements \Maatwebsite\Excel\Concerns\WithHeadingRow {
                public function headingRow(): int { return 1; }
            };

            $datosPropuesta = $filePropuesta ? Excel::toArray($lector, $filePropuesta)[0] : [];
            $datosHistorico = $fileHistorico ? Excel::toArray($lector, $fileHistorico)[0] : [];
            $datosNuevos = $fileNuevos ? Excel::toArray($lector, $fileNuevos)[0] : [];

            DB::transaction(function () use ($datosNuevos, $datosHistorico, $datosPropuesta, $claveSemestre) {
                
                $semestreAnterior = Semestre::where('tipo', 'actual')->first();
                if ($semestreAnterior && $semestreAnterior->clave !== $claveSemestre) {
                    // DESTRUCCIÓN DE HISTORIAL DEL SEMESTRE ANTERIOR
                    DB::table('grupo_tutorado')->delete();
                    DB::table('grupos')->delete();
                    DB::table('semestres')->delete();
                    Semestre::create(['clave' => $claveSemestre, 'tipo' => 'actual']);
                } elseif (!$semestreAnterior) {
                    Semestre::create(['clave' => $claveSemestre, 'tipo' => 'actual']);
                }
                $semestreActual = Semestre::where('tipo', 'actual')->first();

                $cuentasNuevos = [];
                foreach ($datosNuevos as $fila) {
                    $cuenta = $this->extraerCuenta($fila);
                    if ($cuenta) $cuentasNuevos[] = $cuenta;
                }
                if (!empty($cuentasNuevos)) {
                    Tutorado::whereIn('numero_cuenta', $cuentasNuevos)->delete();
                }

                $licenciaturas = Licenciatura::all();
                $sinLicId = 1;
                foreach ($licenciaturas as $l) {
                    if ($this->limpiar($l->abreviatura) === 'S/L') {
                        $sinLicId = $l->id; break;
                    }
                }

                $identificarLicenciatura = function($texto) use ($licenciaturas, $sinLicId) {
                    $txt = $this->limpiar($texto);
                    if (!$txt) return $sinLicId;
                    foreach ($licenciaturas as $l) {
                        if ($txt === $this->limpiar($l->abreviatura) || $txt === $this->limpiar($l->nombre)) return $l->id;
                        $kws = ['COMPUTACION', 'MECANICA', 'SISTEMAS', 'CIVIL', 'ELECTRONICA', 'INTELIGENCIA'];
                        foreach ($kws as $kw) {
                            if (str_contains($this->limpiar($l->nombre), $kw) && str_contains($txt, $kw)) return $l->id;
                        }
                    }
                    return $sinLicId;
                };

                $tutores = Profesor::where('estado', 'Activo')->get();
                $mapaTutores = [];
                foreach ($tutores as $t) {
                    $keyFull = $this->limpiar($t->apellido_paterno) . '_' . $this->limpiar($t->apellido_materno) . '_' . $this->limpiar($t->nombre);
                    $keyParcial = $this->limpiar($t->apellido_paterno) . '__' . $this->limpiar($t->nombre);
                    $mapaTutores[$keyFull] = $t->id;
                    $mapaTutores[$keyParcial] = $t->id;
                }

                $gruposExistentes = Grupo::where('semestre_id', $semestreActual->id)->pluck('id', 'tutor_id')->toArray();
                $nuevosGrupos = [];
                foreach ($tutores as $t) {
                    if (!isset($gruposExistentes[$t->id])) {
                        $nuevosGrupos[] = ['semestre_id' => $semestreActual->id, 'tutor_id' => $t->id, 'estado_tutor' => 'activo', 'created_at' => now(), 'updated_at' => now()];
                    }
                }
                if (!empty($nuevosGrupos)) {
                    Grupo::insert($nuevosGrupos);
                    $gruposExistentes = Grupo::where('semestre_id', $semestreActual->id)->pluck('id', 'tutor_id')->toArray();
                }

                $buscarTutorId = function($fila) use ($mapaTutores) {
                    list($n, $p, $m) = $this->extraerNombresTutor($fila);
                    $pn = $this->limpiar($p);
                    $mn = $this->limpiar($m);
                    $nn = $this->limpiar($n);
                    return $mapaTutores[$pn.'_'.$mn.'_'.$nn] ?? $mapaTutores[$pn.'__'.$nn] ?? null;
                };

                $tutoradosRAM = [];
                $asignaciones = [];
                $cuentasProcesadas = [];
                $nuevosIngresosCuentas = [];

                $procesarFila = function($fila, $esNuevo, $esHistorico, $esPropuesta) use (&$tutoradosRAM, &$asignaciones, &$nuevosIngresosCuentas, &$cuentasProcesadas, $identificarLicenciatura, $sinLicId, $buscarTutorId, $gruposExistentes) {
                    $cuenta = $this->extraerCuenta($fila);
                    if (!$cuenta) return;

                    $licId = $identificarLicenciatura($this->extraerLic($fila));
                    $periodo = trim($fila['semestre_ingreso'] ?? $fila['periodo_ingreso'] ?? 'N/A');
                    list($nom, $apP, $apM) = $this->extraerNombresTutorado($fila);

                    if (!isset($tutoradosRAM[$cuenta])) {
                        $tutoradosRAM[$cuenta] = [
                            'numero_cuenta' => $cuenta,
                            'nombre' => $nom,
                            'apellido_paterno' => $apP,
                            'apellido_materno' => $apM,
                            'periodo_ingreso' => $periodo,
                            'licenciatura_id' => $licId,
                            'is_active' => true,
                        ];
                    } else {
                        if ($tutoradosRAM[$cuenta]['licenciatura_id'] === $sinLicId && $licId !== $sinLicId) $tutoradosRAM[$cuenta]['licenciatura_id'] = $licId;
                        if ($tutoradosRAM[$cuenta]['periodo_ingreso'] === 'N/A' && $periodo !== 'N/A') $tutoradosRAM[$cuenta]['periodo_ingreso'] = $periodo;
                    }

                    $tutorId = $buscarTutorId($fila);

                    if ($esPropuesta) {
                        $estado = $this->extraerEstadoPropuesta($fila);
                        $movilidad = (str_contains($estado, 'CAMBIAR') && !str_contains($estado, 'NO')) ? 'cambiar' : 'no_cambiar';
                        if ($tutorId && isset($gruposExistentes[$tutorId])) {
                            $asignaciones[$cuenta] = ['grupo_id' => $gruposExistentes[$tutorId], 'movilidad' => $movilidad, 'origen' => 'propuesta'];
                        }
                    } elseif ($esHistorico) {
                        if (!isset($asignaciones[$cuenta]) && $tutorId && isset($gruposExistentes[$tutorId])) {
                            $asignaciones[$cuenta] = ['grupo_id' => $gruposExistentes[$tutorId], 'movilidad' => 'cambiar', 'origen' => 'historico'];
                        }
                    } elseif ($esNuevo) {
                        if (isset($asignaciones[$cuenta]) && $asignaciones[$cuenta]['origen'] === 'propuesta') {
                            $asignaciones[$cuenta]['movilidad'] = 'nuevo_ingreso';
                        } else {
                            if ($tutorId && isset($gruposExistentes[$tutorId])) {
                                $asignaciones[$cuenta] = ['grupo_id' => $gruposExistentes[$tutorId], 'movilidad' => 'nuevo_ingreso', 'origen' => 'nuevo'];
                            } else {
                                if (isset($asignaciones[$cuenta])) unset($asignaciones[$cuenta]);
                                $nuevosIngresosCuentas[$cuenta] = true;
                            }
                        }
                    }
                    $cuentasProcesadas[$cuenta] = true;
                };

                foreach ($datosPropuesta as $fila) $procesarFila($fila, false, false, true);
                foreach ($datosHistorico as $fila) $procesarFila($fila, false, true, false);
                foreach ($datosNuevos as $fila) $procesarFila($fila, true, false, false);

                $now = now();
                $tutoradosUpsertFinal = [];
                foreach ($tutoradosRAM as $datos) {
                    $tutoradosUpsertFinal[] = [
                        'numero_cuenta' => $datos['numero_cuenta'],
                        'nombre' => Crypt::encryptString($datos['nombre']),
                        'apellido_paterno' => Crypt::encryptString($datos['apellido_paterno']),
                        'apellido_materno' => Crypt::encryptString($datos['apellido_materno']),
                        'periodo_ingreso' => $datos['periodo_ingreso'],
                        'licenciatura_id' => $datos['licenciatura_id'],
                        'is_active' => $datos['is_active'],
                        'created_at' => $now,
                        'updated_at' => $now,
                    ];
                }

                $chunks = array_chunk($tutoradosUpsertFinal, 1000);
                foreach ($chunks as $chunk) {
                    Tutorado::upsert($chunk, ['numero_cuenta'], ['nombre', 'apellido_paterno', 'apellido_materno', 'periodo_ingreso', 'licenciatura_id', 'is_active', 'updated_at']);
                }

                Tutorado::whereNotIn('numero_cuenta', array_keys($cuentasProcesadas))->update(['is_active' => false]);
                
                $tutoradosDbRaw = Tutorado::whereIn('numero_cuenta', array_keys($cuentasProcesadas))->pluck('id', 'numero_cuenta')->toArray();
                $tutoradosDbStrings = [];
                foreach ($tutoradosDbRaw as $k => $v) $tutoradosDbStrings[(string)$k] = $v;

                $matrizAsignaciones = []; 
                foreach ($asignaciones as $cuenta => $datos) {
                    if (isset($tutoradosDbStrings[(string)$cuenta])) {
                        $matrizAsignaciones[$tutoradosDbStrings[(string)$cuenta]] = $datos;
                    }
                }

                $tutoresLic = DB::table('licenciatura_profesor')->get()->groupBy('licenciatura_id');
                $poolGlobalTutoresIds = $tutores->pluck('id')->toArray();

                foreach ($licenciaturas as $lic) {
                    $profesoresLicIds = $tutoresLic->get($lic->id)?->pluck('profesor_id')->toArray() ?? [];
                    if (empty($profesoresLicIds)) $profesoresLicIds = $poolGlobalTutoresIds;

                    $gruposLicIds = array_intersect_key($gruposExistentes, array_flip($profesoresLicIds));
                    if (empty($gruposLicIds)) continue;

                    $capacidadTutores = array_fill_keys($gruposLicIds, 0);
                    $alumnosLicDb = Tutorado::where('licenciatura_id', $lic->id)->where('is_active', true)->pluck('numero_cuenta', 'id')->toArray();

                    foreach ($alumnosLicDb as $tutoradoId => $cuentaDb) {
                        if (isset($matrizAsignaciones[$tutoradoId])) {
                            $gId = $matrizAsignaciones[$tutoradoId]['grupo_id'];
                            if (isset($capacidadTutores[$gId])) $capacidadTutores[$gId]++;
                        }
                    }

                    $nuevosLicIds = [];
                    foreach ($alumnosLicDb as $tutoradoId => $cuentaDb) {
                        $cuentaLimpia = preg_replace('/[^0-9A-Za-z]/', '', (string)$cuentaDb);
                        if (isset($nuevosIngresosCuentas[$cuentaLimpia])) {
                            $nuevosLicIds[] = $tutoradoId;
                        }
                    }
                    shuffle($nuevosLicIds);

                    foreach ($nuevosLicIds as $tutoradoId) {
                        asort($capacidadTutores);
                        $grupoMinId = array_key_first($capacidadTutores);
                        $matrizAsignaciones[$tutoradoId] = ['grupo_id' => $grupoMinId, 'movilidad' => 'nuevo_ingreso'];
                        $capacidadTutores[$grupoMinId]++;
                    }

                    $lockedGroups = [];
                    while (true) {
                        asort($capacidadTutores);
                        $minGroupId = array_key_first($capacidadTutores);
                        $minCount = $capacidadTutores[$minGroupId];

                        arsort($capacidadTutores);
                        $maxGroupId = null;
                        $maxCount = -1;
                        foreach ($capacidadTutores as $gId => $c) {
                            if (!in_array($gId, $lockedGroups)) {
                                $maxGroupId = $gId; $maxCount = $c; break;
                            }
                        }

                        if ($maxGroupId === null || ($maxCount - $minCount) <= 1) break;

                        $candidatoId = null;
                        foreach ($matrizAsignaciones as $tId => $data) {
                            if ($data['grupo_id'] === $maxGroupId && in_array($data['movilidad'], ['cambiar', 'nuevo_ingreso']) && isset($alumnosLicDb[$tId])) {
                                $candidatoId = $tId; break;
                            }
                        }

                        if ($candidatoId) {
                            $matrizAsignaciones[$candidatoId]['grupo_id'] = $minGroupId;
                            $capacidadTutores[$maxGroupId]--;
                            $capacidadTutores[$minGroupId]++;
                        } else {
                            $lockedGroups[] = $maxGroupId;
                        }
                    }
                }

                $asignadosIds = array_keys($matrizAsignaciones);
                $nuevosIngresosIds = [];
                foreach ($nuevosIngresosCuentas as $cuenta => $val) {
                    if (isset($tutoradosDbStrings[(string)$cuenta])) {
                        $nuevosIngresosIds[] = $tutoradosDbStrings[(string)$cuenta];
                    }
                }
                
                $huerfanos = array_diff($nuevosIngresosIds, $asignadosIds);
                if (!empty($huerfanos) && !empty($gruposExistentes)) {
                    $capacidadGlobal = array_fill_keys(array_values($gruposExistentes), 0);
                    foreach ($matrizAsignaciones as $datos) {
                        if (isset($capacidadGlobal[$datos['grupo_id']])) $capacidadGlobal[$datos['grupo_id']]++;
                    }
                    foreach ($huerfanos as $mId) {
                        asort($capacidadGlobal);
                        $grupoGlobalMin = array_key_first($capacidadGlobal);
                        $matrizAsignaciones[$mId] = ['grupo_id' => $grupoGlobalMin, 'movilidad' => 'nuevo_ingreso'];
                        $capacidadGlobal[$grupoGlobalMin]++;
                    }
                }

                DB::table('grupo_tutorado')->where('semestre_id', $semestreActual->id)->delete();
                $pivotInserts = [];
                foreach ($matrizAsignaciones as $tutoradoId => $datos) {
                    $pivotInserts[] = [
                        'tutorado_id' => $tutoradoId,
                        'semestre_id' => $semestreActual->id,
                        'grupo_id' => $datos['grupo_id'],
                        'estado_tutorado' => 'activo',
                        'movilidad' => $datos['movilidad'],
                        'created_at' => now(),
                        'updated_at' => now(),
                    ];
                }

                $chunksPivot = array_chunk($pivotInserts, 1000);
                foreach ($chunksPivot as $chunk) {
                    DB::table('grupo_tutorado')->insert($chunk);
                }
            });

            return ['success' => true, 'message' => 'Carga de datos completada correctamente.'];
        } catch (\Throwable $e) {
            return ['success' => false, 'error' => 'Error backend: ' . $e->getMessage() . ' Linea: ' . $e->getLine()];
        }
    }
}