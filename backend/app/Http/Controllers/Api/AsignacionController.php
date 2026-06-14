<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Profesor;
use App\Models\Licenciatura;
use App\Models\Semestre;
use App\Models\Grupo;
use Illuminate\Http\Request;

class AsignacionController extends Controller
{
    public function index(Request $request)
    {
        // 1. Traer todos los semestres
        $semestres = Semestre::all();

        // 2. Determinar el semestre objetivo según el filtro de la URL (?semestre=2024A)
        $filtroSemestre = $request->query('semestre');
        $semestreObjetivo = null;

        if ($filtroSemestre && $filtroSemestre !== 'Todos') {
            $semestreObjetivo = $semestres->firstWhere('clave', $filtroSemestre);
        } else {
            $semestreObjetivo = Semestre::where('tipo', 'actual')->first();
        }

        // 3. Si no hay semestre objetivo, devolver respuesta vacía
        if (!$semestreObjetivo) {
            return response()->json([
                'semestres'    => $semestres,
                'tutores'      => [],
                'licenciaturas'=> Licenciatura::all(),
            ]);
        }

        // 4. Cargar todos los grupos del semestre objetivo con sus relaciones
        //    - tutor → licenciaturas (para las carreras del tutor)
        //    - tutorados → licenciatura (para la carrera del alumno)
        //      incluyendo los campos del pivot grupo_tutorado
        $grupos = Grupo::with([
            'tutor.licenciaturas',
            'tutorados.licenciatura',
        ])
        ->where('semestre_id', $semestreObjetivo->id)
        ->get();

        // 5. Agrupar por tutor y construir la estructura que Flutter espera:
        //    tutores[ { id, nombre, apellido_paterno, estado, licenciaturas[], grupos[ { tutorados[] } ] } ]
        $tutoresMap = [];

        foreach ($grupos as $grupo) {
            $tutor = $grupo->tutor;
            if (!$tutor) continue;

            $tutorId = $tutor->id;

            // Inicializar el tutor si no existe aún en el mapa
            if (!isset($tutoresMap[$tutorId])) {
                $tutoresMap[$tutorId] = [
                    'id'              => $tutorId,
                    'nombre'          => $tutor->nombre,
                    'apellido_paterno'=> $tutor->apellido_paterno,
                    'apellido_materno'=> $tutor->apellido_materno,
                    'correo'          => $tutor->correo,
                    'estado'          => $tutor->estado,
                    'licenciaturas'   => $tutor->licenciaturas->map(fn($l) => [
                        'id'          => $l->id,
                        'codigo'      => $l->codigo,
                        'abreviatura' => $l->abreviatura,
                        'nombre'      => $l->nombre,
                    ])->values()->toArray(),
                    'grupos' => [],
                ];
            }

            // Construir la lista de tutorados de este grupo
            $tutorados = $grupo->tutorados->map(function ($tutorado) {
                $pivot = $tutorado->pivot;
                return [
                    'id'               => $tutorado->id,
                    'numero_cuenta'    => $tutorado->numero_cuenta,
                    'nombre'           => $tutorado->nombre,
                    'apellido_paterno' => $tutorado->apellido_paterno,
                    'apellido_materno' => $tutorado->apellido_materno,
                    'periodo_ingreso'  => $tutorado->periodo_ingreso,
                    'is_active'        => $tutorado->is_active,
                    'licenciatura'     => $tutorado->licenciatura ? [
                        'id'          => $tutorado->licenciatura->id,
                        'abreviatura' => $tutorado->licenciatura->abreviatura,
                        'nombre'      => $tutorado->licenciatura->nombre,
                    ] : null,
                    'pivot' => [
                        'movilidad'       => $pivot->movilidad       ?? 'no_cambiar',
                        'estado_tutorado' => $pivot->estado_tutorado ?? 'activo',
                        'semestre_id'     => $pivot->semestre_id,
                    ],
                ];
            })->values()->toArray();

            // Agregar el grupo al tutor
            $tutoresMap[$tutorId]['grupos'][] = [
                'id'           => $grupo->id,
                'semestre_id'  => $grupo->semestre_id,
                'estado_tutor' => $grupo->estado_tutor,
                'tutorados'    => $tutorados,
            ];
        }

        return response()->json([
            'semestres'     => $semestres,
            'tutores'       => array_values($tutoresMap),
            'licenciaturas' => Licenciatura::all(),
        ]);
    }
}