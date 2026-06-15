<?php

namespace App\Services;

use App\Models\Semestre;
use App\Models\Tutorado;
use App\Models\Profesor;
use App\Models\Grupo;
use App\Models\Licenciatura;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Log;
use Maatwebsite\Excel\Facades\Excel;

class CargaTutoriasService
{
    private function limpiar(?string $t): string
    {
        if (!$t) return '';
        $b = ['á','é','í','ó','ú','Á','É','Í','Ó','Ú','ñ','Ñ','ä','ë','ï','ö','ü'];
        $r = ['a','e','i','o','u','A','E','I','O','U','n','N','a','e','i','o','u'];
        return strtoupper(preg_replace('/\s+/', '', trim(str_replace($b, $r, $t))));
    }

    private function limpiarCuenta($v): string
    {
        return preg_replace('/[^0-9]/', '', preg_replace('/\.0+$/', '', trim((string)($v ?? ''))));
    }

    private function extraerCuenta(array $f): string
    {
        foreach ($f as $v) { $val = $this->limpiarCuenta($v); if (strlen($val) === 7) return $val; }
        foreach ($f as $k => $v) {
            $kl = strtolower(trim((string)$k));
            if (str_contains($kl,'cuenta')||str_contains($kl,'numero')||str_contains($kl,'n_mero')) {
                $val = $this->limpiarCuenta($v); if ($val !== '') return $val;
            }
        }
        return '';
    }

    private function sortedKey(string $a, string $b, string $c): string
    {
        $p = array_filter([$this->limpiar($a),$this->limpiar($b),$this->limpiar($c)], fn($x)=>$x!=='');
        sort($p); return implode('|', $p);
    }

    private function gruposActivosPorLic($pa, int $lid, array $gm): array
    {
        $r = [];
        foreach ($pa as $p) {
            if (!$p->licenciaturas->contains('id',$lid)) continue;
            $k = $p->id.'_'.$lid; if (isset($gm[$k])) $r[] = $gm[$k];
        }
        return $r;
    }

    // ══════════════════════════════════════════════════════════════
    public function procesarCargaMasiva($fileNuevos, $fileHistorico, $filePropuesta, $claveSemestre)
    {
        ini_set('max_execution_time','0');
        ini_set('memory_limit','-1');
        DB::connection()->disableQueryLog();

        try {
            // ── FASE 1: LEER ARCHIVOS ──
            $rawHist = [];
            if ($fileHistorico) {
                $all = Excel::toArray(new class {}, $fileHistorico)[0] ?? [];
                array_shift($all); $rawHist = $all;
            }
            $lec = new class implements \Maatwebsite\Excel\Concerns\WithHeadingRow { public function headingRow(): int { return 1; } };
            $rawProp   = $filePropuesta ? (Excel::toArray($lec,$filePropuesta)[0] ?? []) : [];
            $rawNuevos = $fileNuevos    ? (Excel::toArray($lec,$fileNuevos)[0] ?? [])    : [];

            Log::info("Carga: H=".count($rawHist)." N=".count($rawNuevos)." P=".count($rawProp));

            DB::transaction(function() use ($rawHist,$rawNuevos,$rawProp,$claveSemestre) {

                // ── FASE 2: SEMESTRE ──
                DB::table('grupo_tutorado')->delete();
                DB::table('grupos')->delete();
                $sem = Semestre::where('tipo','actual')->first();
                if (!$sem || $sem->clave !== $claveSemestre) {
                    DB::table('semestres')->delete();
                    Semestre::create(['clave'=>$claveSemestre,'tipo'=>'actual']);
                }
                $semA = Semestre::where('tipo','actual')->first();

                // ── FASE 3: REFERENCIAS ──
                $lics = Licenciatura::all();
                $sinLicId = $lics->first(fn($l)=>$this->limpiar($l->abreviatura)==='S/L')?->id ?? 1;
                $licMap = []; foreach ($lics as $l) $licMap[$this->limpiar($l->abreviatura)] = $l->id;
                $idLic = fn(string $t) => $licMap[$this->limpiar($t)] ?? $sinLicId;

                $profs = Profesor::with('licenciaturas')->get();
                $pm = []; // sortedKey → [prof,...]
                foreach ($profs as $p) {
                    $k = $this->sortedKey($p->apellido_paterno,$p->apellido_materno,$p->nombre);
                    if ($k) $pm[$k][] = $p;
                }

                // Búsqueda ESTRICTA por licenciatura. $licId=null → sin restricción (Propuesta-only).
                $buscar = function(string $a, string $b, string $c, ?int $licId) use ($pm): ?Profesor {
                    $k = $this->sortedKey($a,$b,$c);
                    if (!$k || !isset($pm[$k])) return null;
                    if ($licId !== null) {
                        foreach ($pm[$k] as $p) { if ($p->licenciaturas->contains('id',$licId)) return $p; }
                        return null;
                    }
                    foreach ($pm[$k] as $p) { if ($p->estado==='Activo') return $p; }
                    return $pm[$k][0];
                };

                // ── FASE 4: TUTORADOS EN RAM ──
                $ram = [];

                // 4a: HISTÓRICO (posicional) → 'cambiar'
                foreach ($rawHist as $row) {
                    $v = array_values($row);
                    $cta = $this->limpiarCuenta($v[1] ?? ''); if (!$cta) continue;
                    $licId = $idLic(trim((string)($v[0] ?? '')));
                    $prof = $buscar(trim((string)($v[6]??'')),trim((string)($v[7]??'')),trim((string)($v[8]??'')),$licId);
                    $ram[$cta] = [
                        'apellido_paterno'=>trim((string)($v[2]??'')),
                        'apellido_materno'=>trim((string)($v[3]??'')),
                        'nombre'=>trim((string)($v[4]??'')),
                        'periodo_ingreso'=>trim((string)($v[5]??'')),
                        'licenciatura_id'=>$licId, 'movilidad'=>'cambiar', 'profesor_id'=>$prof?->id,
                    ];
                }

                // 4b: NUEVO INGRESO → 'nuevo_ingreso'
                foreach ($rawNuevos as $f) {
                    $cta = $this->extraerCuenta($f); if (!$cta) continue;
                    $licId = $idLic(trim((string)($f['licenciatura_tutorado'] ?? '')));
                    if (isset($ram[$cta])) {
                        if ($ram[$cta]['licenciatura_id']===$sinLicId && $licId!==$sinLicId) $ram[$cta]['licenciatura_id']=$licId;
                        if (!$ram[$cta]['profesor_id']) $ram[$cta]['movilidad']='nuevo_ingreso';
                    } else {
                        $ram[$cta] = [
                            'apellido_paterno'=>trim((string)($f['apellido_paterno_tutorado']??'')),
                            'apellido_materno'=>trim((string)($f['apellido_materno_tutorado']??'')),
                            'nombre'=>trim((string)($f['nombre_del_tutorado']??'')),
                            'periodo_ingreso'=>trim((string)($f['semestre_ingreso']??$claveSemestre)),
                            'licenciatura_id'=>$licId, 'movilidad'=>'nuevo_ingreso', 'profesor_id'=>null,
                        ];
                    }
                }

                // 4c: PROPUESTA → 'no_cambiar' (estricto para existentes, libre para solo-propuesta)
                foreach ($rawProp as $f) {
                    $cta = $this->extraerCuenta($f); if (!$cta) continue;
                    $tA=trim((string)($f['apellido_paterno_tutor']??''));
                    $tB=trim((string)($f['apellido_materno_tutor']??''));
                    $tC=trim((string)($f['nombre_del_tutor']??''));

                    if (isset($ram[$cta])) {
                        $prof = $buscar($tA,$tB,$tC,$ram[$cta]['licenciatura_id']);
                        $ram[$cta]['movilidad'] = 'no_cambiar';
                        if ($prof) $ram[$cta]['profesor_id'] = $prof->id;
                    } else {
                        $prof = $buscar($tA,$tB,$tC,null);
                        $licId = $sinLicId;
                        if ($prof && $prof->licenciaturas->isNotEmpty()) $licId = $prof->licenciaturas->first()->id;
                        $ram[$cta] = [
                            'apellido_paterno'=>trim((string)($f['apellido_paterno_tutorado']??'')),
                            'apellido_materno'=>trim((string)($f['apellido_materno_tutorado']??'')),
                            'nombre'=>trim((string)($f['nombre_del_tutorado']??'')),
                            'periodo_ingreso'=>'N/A',
                            'licenciatura_id'=>$licId, 'movilidad'=>'no_cambiar', 'profesor_id'=>$prof?->id,
                        ];
                    }
                }

                // ── FASE 5: UPSERT BD ──
                $now = now(); $ups = [];
                foreach ($ram as $cta => $d) {
                    $ups[] = [
                        'numero_cuenta'=>(string)$cta,
                        'nombre'=>Crypt::encryptString($d['nombre']),
                        'apellido_paterno'=>Crypt::encryptString($d['apellido_paterno']),
                        'apellido_materno'=>Crypt::encryptString($d['apellido_materno']??''),
                        'periodo_ingreso'=>$d['periodo_ingreso'], 'licenciatura_id'=>$d['licenciatura_id'],
                        'is_active'=>true, 'created_at'=>$now, 'updated_at'=>$now,
                    ];
                }
                foreach (array_chunk($ups,500) as $ch)
                    Tutorado::upsert($ch,['numero_cuenta'],['nombre','apellido_paterno','apellido_materno','periodo_ingreso','licenciatura_id','is_active','updated_at']);
                Tutorado::whereNotIn('numero_cuenta',array_keys($ram))->update(['is_active'=>false]);

                $ctaId = [];
                foreach (Tutorado::whereIn('numero_cuenta',array_keys($ram))->pluck('id','numero_cuenta') as $c=>$id)
                    $ctaId[(string)$c] = $id;

                // ── FASE 6: CREAR GRUPOS (tutor activo × licenciatura) ──
                $pa = $profs->where('estado','Activo');
                $bulk = [];
                foreach ($pa as $p) foreach ($p->licenciaturas as $l) {
                    if ($l->id===$sinLicId) continue;
                    $bulk[] = ['semestre_id'=>$semA->id,'tutor_id'=>$p->id,'licenciatura_id'=>$l->id,
                               'estado_tutor'=>'activo','created_at'=>$now,'updated_at'=>$now];
                }
                if ($bulk) Grupo::insert($bulk);
                $gMap = [];
                foreach (Grupo::where('semestre_id',$semA->id)->get() as $g)
                    $gMap[$g->tutor_id.'_'.$g->licenciatura_id] = $g->id;

                // ── FASE 7: ASIGNAR ──
                //
                // REGLA BAJA: Si el tutor está en estado de baja, TODOS sus
                // alumnos pasan a 'cambiar' y van a redistribución, sin excepción.
                //
                $asig = []; $poolN = []; $poolR = [];

                foreach ($ram as $cta => $d) {
                    $dbId = $ctaId[(string)$cta] ?? null; if (!$dbId) continue;
                    $licId=$d['licenciatura_id']; $pId=$d['profesor_id']; $mov=$d['movilidad'];

                    if ($mov==='nuevo_ingreso' && !$pId) { $poolN[$licId][]=$dbId; continue; }
                    if (!$pId) { $poolR[$licId][]=['id'=>$dbId,'mov'=>$mov]; continue; }

                    // ★ TUTOR DE BAJA → todos sus alumnos a 'cambiar' + redistribuir ★
                    $po = $profs->firstWhere('id',$pId);
                    if (!$po || $po->estado !== 'Activo') {
                        $poolR[$licId][] = ['id'=>$dbId,'mov'=>'cambiar'];
                        continue;
                    }

                    $gId = $gMap[$pId.'_'.$licId] ?? null;
                    if ($gId) { $asig[$dbId]=['grupo_id'=>$gId,'movilidad'=>$mov]; }
                    else      { $poolR[$licId][]=['id'=>$dbId,'mov'=>$mov]; }
                }

                // ── FASE 8: ROUND-ROBIN NUEVO INGRESO ──
                $cap = array_fill_keys(array_values($gMap),0);
                foreach ($asig as $d) { if (isset($cap[$d['grupo_id']])) $cap[$d['grupo_id']]++; }

                foreach ($poolN as $lid => $ids) {
                    $gs = $this->gruposActivosPorLic($pa,$lid,$gMap);
                    if (!$gs) { foreach ($ids as $id) $poolR[$lid][]=['id'=>$id,'mov'=>'nuevo_ingreso']; continue; }
                    usort($gs, fn($a,$b)=>($cap[$a]??0)<=>($cap[$b]??0));
                    $i=0; $t=count($gs);
                    foreach ($ids as $id) {
                        $g=$gs[$i%$t]; $asig[$id]=['grupo_id'=>$g,'movilidad'=>'nuevo_ingreso'];
                        $cap[$g]=($cap[$g]??0)+1; $i++;
                    }
                }

                // ── FASE 9: REDISTRIBUIR (conservando movilidad) ──
                foreach ($poolR as $lid => $items) {
                    $gs = $this->gruposActivosPorLic($pa,$lid,$gMap);
                    if (!$gs) { Log::warning("Redist: ".count($items)." sin grupo lid=$lid"); continue; }
                    foreach ($items as $it) {
                        usort($gs, fn($a,$b)=>($cap[$a]??0)<=>($cap[$b]??0));
                        $asig[$it['id']]=['grupo_id'=>$gs[0],'movilidad'=>$it['mov']];
                        $cap[$gs[0]]=($cap[$gs[0]]??0)+1;
                    }
                }

                // ── FASE 10: REBALANCEO ──
                foreach ($lics as $lic) {
                    if ($lic->id===$sinLicId) continue;
                    $gs = $this->gruposActivosPorLic($pa,$lic->id,$gMap);
                    if (count($gs)<=1) continue;
                    $cl=[]; foreach ($gs as $g) $cl[$g]=$cap[$g]??0;
                    $mv=[];
                    foreach ($asig as $tId=>$d) {
                        if (!in_array($d['grupo_id'],$gs)) continue;
                        if ($d['movilidad']==='nuevo_ingreso') $mv[$d['grupo_id']][]=['id'=>$tId,'p'=>0];
                        elseif ($d['movilidad']==='cambiar')   $mv[$d['grupo_id']][]=['id'=>$tId,'p'=>1];
                    }
                    foreach ($mv as &$ls) usort($ls, fn($a,$b)=>$a['p']<=>$b['p']); unset($ls);
                    $lk=[];
                    for ($it=0;$it<5000;$it++) {
                        $mnG=null;$mnC=PHP_INT_MAX;$mxG=null;$mxC=-1;
                        foreach ($cl as $g=>$c) {
                            if ($c<$mnC){$mnC=$c;$mnG=$g;} if ($c>$mxC&&!in_array($g,$lk)){$mxC=$c;$mxG=$g;}
                        }
                        if (!$mxG||($mxC-$mnC)<=1) break;
                        if (!empty($mv[$mxG])) {
                            $cd=array_shift($mv[$mxG]); $asig[$cd['id']]['grupo_id']=$mnG;
                            $cl[$mxG]--;$cl[$mnG]++;$cap[$mxG]--;$cap[$mnG]++;$mv[$mnG][]=$cd;
                        } else { $lk[]=$mxG; }
                    }
                }

                // ── FASE 11: INSERT BD ──
                $ins=[];
                foreach ($asig as $tId=>$d)
                    $ins[]=['tutorado_id'=>$tId,'semestre_id'=>$semA->id,'grupo_id'=>$d['grupo_id'],
                            'estado_tutorado'=>'activo','movilidad'=>$d['movilidad'],'created_at'=>$now,'updated_at'=>$now];
                foreach (array_chunk($ins,1000) as $ch) DB::table('grupo_tutorado')->insert($ch);

                $conA = DB::table('grupo_tutorado')->where('semestre_id',$semA->id)->pluck('grupo_id')->unique()->toArray();
                Grupo::where('semestre_id',$semA->id)->whereNotIn('id',$conA)->delete();

                Log::info("Carga COMPLETA: ".count($ins)." asignaciones");
            });
            return ['success'=>true,'message'=>'Carga completada correctamente.'];
        } catch (\Throwable $e) {
            Log::error("Carga ERROR: ".$e->getMessage()." L:".$e->getLine());
            return ['success'=>false,'error'=>'Error: '.$e->getMessage().' Linea: '.$e->getLine()];
        }
    }
}