<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use App\Models\User;
use App\Models\Licenciatura;
use App\Models\Profesor;
use App\Models\Tutorado;
use App\Models\Grupo;
use App\Models\Semestre;
use PragmaRX\Google2FA\Google2FA;
use Illuminate\Support\Facades\Response;
use Illuminate\Support\Facades\Storage;
use App\Http\Controllers\CargaDatosController;
use App\Http\Controllers\Api\AsignacionController;
use App\Http\Controllers\Api\SemestreController;
use App\Http\Controllers\ProfesorController;

// ══════════════════════════════════════════════════════════════════
//  AUTH / USUARIOS
// ══════════════════════════════════════════════════════════════════

Route::post('/login', function (Request $request) {
    $request->validate([
        'email' => 'required',
        'password' => 'required',
    ]);

    $userCount = User::count();

    if ($userCount === 0 && $request->email === 'admin' && $request->password === 'admin') {
        $user = User::create([
            'name' => 'Administrador de Sistema',
            'email' => 'admin@admin.com',
            'password' => Hash::make(Str::random(32)),
            'mfa_enabled' => false
        ]);

        return response()->json([
            'status' => 'SUCCESS',
            'token' => $user->createToken('auth_token')->plainTextToken,
            'first_login' => true,
            'user_name' => $user->name
        ], 200);
    }

    $user = User::where('email', $request->email)->first();

    if (!$user || !Hash::check($request->password, $user->password)) {
        return response()->json(['message' => 'Unauthorized'], 401);
    }

    return response()->json([
        'status' => 'SUCCESS',
        'token' => $user->createToken('auth_token')->plainTextToken,
        'first_login' => false,
        'user_name' => $user->name
    ], 200);
});

Route::middleware('auth:sanctum')->post('/mfa/verify', function (Request $request) {
    $request->validate([
        'mfa_code' => 'required|string',
        'new_password' => 'nullable|string|min:6'
    ]);

    $user = $request->user();
    $google2fa = new \PragmaRX\Google2FA\Google2FA();

    $valid = $google2fa->verifyKey($user->mfa_secret, $request->mfa_code);

    if ($valid) {
        if ($request->has('new_password')) {
            $user->password = Hash::make($request->new_password);
            $user->save();
            $user->tokens()->delete();
            return response()->json(['status' => 'SUCCESS', 'message' => 'Password updated']);
        }

        $user->tokens()->where('name', 'mfa_temp')->delete();
        return response()->json([
            'status' => 'SUCCESS',
            'token' => $user->createToken('auth_token')->plainTextToken,
            'user_name' => $user->name
        ], 200);
    }

    return response()->json(['status' => 'FAILED'], 401);
});

Route::post('/usuarios/crear', function (Request $request) {
    $request->validate([
        'name' => 'required',
        'email' => 'required|email|unique:users',
        'password' => 'required|min:6'
    ]);

    $google2fa = new Google2FA();
    $secret = $google2fa->generateSecretKey();

    $user = User::create([
        'name' => $request->name,
        'email' => $request->email,
        'password' => bcrypt($request->password),
        'mfa_enabled' => true,
        'mfa_secret' => $secret
    ]);

    User::where('email', 'admin@admin.com')->delete();

    $qrUrl = "otpauth://totp/TutorAssign:{$user->email}?secret={$secret}&issuer=TutorAssign";

    return response()->json([
        'message' => 'Usuario creado',
        'qr_auth_url' => $qrUrl
    ], 201);
});

Route::post('/usuarios/update-password', function (Request $request) {
    $request->validate([
        'email' => 'required|email',
        'old_password' => 'required',
        'new_password' => 'required|min:6',
    ]);

    $user = User::where('email', $request->email)->first();

    if (!$user || !Hash::check($request->old_password, $user->password)) {
        return response()->json(['message' => 'Credenciales actuales incorrectas'], 401);
    }

    $user->password = bcrypt($request->new_password);
    $user->save();

    return response()->json(['message' => 'Contraseña actualizada correctamente']);
});

Route::post('/login/mfa-start', function (Request $request) {
    $request->validate(['email' => 'required|email']);

    $user = User::where('email', $request->email)->first();

    if (!$user) {
        return response()->json(['message' => 'Usuario no encontrado'], 404);
    }

    return response()->json([
        'status' => 'MFA_REQUIRED',
        'temp_token' => $user->createToken('mfa_temp')->plainTextToken
    ], 200);
});

Route::get('/usuarios', function () {
    return response()->json(User::select('id', 'name', 'email', 'mfa_enabled')->get());
});

Route::delete('/usuarios/{id}', function ($id) {
    User::destroy($id);
    return response()->json(['status' => 'SUCCESS']);
});

// ══════════════════════════════════════════════════════════════════
//  BACKUP
// ══════════════════════════════════════════════════════════════════

Route::get('/backup/export', function (Request $request) {
    $filename = $request->query('filename', 'respaldo.sql');
    $path = storage_path('app/' . $filename);

    $dockerDumpCmd = "docker exec -e PGPASSWORD=PasswordSeguro123 tutoria_db_final pg_dump -U admin_tutoria -d tutoria_db -F c -f /tmp/{$filename}";
    exec($dockerDumpCmd);

    $dockerCpCmd = "docker cp tutoria_db_final:/tmp/{$filename} \"{$path}\"";
    exec($dockerCpCmd);

    if (file_exists($path)) {
        return Response::download($path, $filename)->deleteFileAfterSend(true);
    }

    return response()->json(['error' => 'No se pudo generar el respaldo'], 500);
});

Route::post('/backup/import', function (Request $request) {
    $request->validate([
        'backup_file' => 'required|file'
    ]);

    $file = $request->file('backup_file');
    $path = $file->storeAs('backups', 'restore.sql', 'local');

    $fullPath = Storage::disk('local')->path($path);

    $header = file_get_contents($fullPath, false, null, 0, 5);
    $isCustomFormat = ($header === 'PGDMP');

    $dockerCpCmd = "docker cp \"{$fullPath}\" tutoria_db_final:/tmp/restore.sql";
    exec($dockerCpCmd);

    $dockerCleanCmd = "docker exec -e PGPASSWORD=PasswordSeguro123 tutoria_db_final psql -U admin_tutoria -d tutoria_db -c \"DROP SCHEMA public CASCADE; CREATE SCHEMA public;\"";
    exec($dockerCleanCmd);

    if ($isCustomFormat) {
        $restoreCmd = "docker exec -e PGPASSWORD=PasswordSeguro123 tutoria_db_final pg_restore -U admin_tutoria -d tutoria_db -O -x /tmp/restore.sql 2>&1";
    } else {
        $restoreCmd = "docker exec -e PGPASSWORD=PasswordSeguro123 tutoria_db_final psql -U admin_tutoria -d tutoria_db -f /tmp/restore.sql 2>&1";
    }

    exec($restoreCmd, $output, $returnVar);

    Storage::disk('local')->delete($path);
    exec("docker exec tutoria_db_final rm /tmp/restore.sql");

    if (in_array($returnVar, [0, 1, 3])) {
        return response()->json(['status' => 'SUCCESS']);
    }

    \Illuminate\Support\Facades\Log::error("Error restaurando DB:\n" . implode("\n", $output));
    return response()->json(['status' => 'FAILED'], 500);
});

// ══════════════════════════════════════════════════════════════════
//  LICENCIATURAS (CRUD)
// ══════════════════════════════════════════════════════════════════

Route::get('/licenciaturas', function () {
    return response()->json(Licenciatura::all());
});

Route::post('/licenciaturas', function (Request $request) {
    $request->validate([
        'abreviatura' => 'required|string',
        'nombre' => 'required|string',
    ]);

    $last = Licenciatura::orderBy('id', 'desc')->first();
    $nextId = $last ? $last->id + 1 : 1;
    $codigo = 'C' . str_pad($nextId, 2, '0', STR_PAD_LEFT);

    $licenciatura = Licenciatura::create([
        'codigo' => $codigo,
        'abreviatura' => $request->abreviatura,
        'nombre' => $request->nombre
    ]);
    return response()->json(['status' => 'SUCCESS', 'data' => $licenciatura]);
});

Route::put('/licenciaturas/{id}', function (Request $request, $id) {
    $licenciatura = Licenciatura::findOrFail($id);
    $request->validate([
        'abreviatura' => 'required|string',
        'nombre' => 'required|string',
    ]);

    $licenciatura->update([
        'abreviatura' => $request->abreviatura,
        'nombre' => $request->nombre
    ]);
    return response()->json(['status' => 'SUCCESS', 'data' => $licenciatura]);
});

Route::delete('/licenciaturas/{id}', function ($id) {
    try {
        DB::beginTransaction();

        $sinLic = Licenciatura::firstOrCreate(
            ['abreviatura' => 'S/L'],
            ['codigo' => 'C00', 'nombre' => 'Sin licenciatura']
        );

        if ($id == $sinLic->id) {
            return response()->json(['status' => 'FAILED', 'error' => 'No se puede eliminar la categoría de respaldo.'], 403);
        }

        Tutorado::where('licenciatura_id', $id)->update(['licenciatura_id' => $sinLic->id]);

        $profesores = Profesor::whereHas('licenciaturas', function ($query) use ($id) {
            $query->where('licenciaturas.id', $id);
        })->get();

        foreach ($profesores as $profesor) {
            $profesor->licenciaturas()->detach($id);

            if ($profesor->licenciaturas()->count() === 0) {
                $profesor->licenciaturas()->attach($sinLic->id);
            }
        }

        Licenciatura::destroy($id);

        DB::commit();
        return response()->json(['status' => 'SUCCESS']);

    } catch (\Exception $e) {
        DB::rollBack();
        return response()->json(['status' => 'FAILED', 'error' => $e->getMessage()], 500);
    }
});

// ══════════════════════════════════════════════════════════════════
//  PROFESORES
// ══════════════════════════════════════════════════════════════════

Route::get('/profesores', function () {
    return response()->json(Profesor::with('licenciaturas')->get());
});

Route::post('/profesores', function (Request $request) {
    $request->validate([
        'nombre' => 'required|string',
        'apellido_paterno' => 'required|string',
        'apellido_materno' => 'nullable|string',
        'correo' => 'nullable|email',
        'carreras' => 'required|array',
        'estado' => 'required|string',
    ]);

    $profesor = Profesor::create([
        'nombre' => $request->nombre,
        'apellido_paterno' => $request->apellido_paterno,
        'apellido_materno' => $request->apellido_materno ?? '',
        'correo' => $request->correo ?? '',
        'estado' => $request->estado,
    ]);

    $licenciaturas = Licenciatura::whereIn('abreviatura', $request->carreras)->pluck('id');
    $profesor->licenciaturas()->sync($licenciaturas);

    return response()->json(['status' => 'SUCCESS']);
});

Route::put('/profesores/{id}', function (Request $request, $id) {
    $profesor = Profesor::findOrFail($id);

    $request->validate([
        'nombre' => 'required|string',
        'apellido_paterno' => 'required|string',
        'apellido_materno' => 'nullable|string',
        'correo' => 'nullable|email',
        'carreras' => 'required|array',
        'estado' => 'required|string',
    ]);

    $profesor->update([
        'nombre' => $request->nombre,
        'apellido_paterno' => $request->apellido_paterno,
        'apellido_materno' => $request->apellido_materno ?? '',
        'correo' => $request->correo ?? '',
        'estado' => $request->estado,
    ]);

    $licenciaturas = Licenciatura::whereIn('abreviatura', $request->carreras)->pluck('id');
    $profesor->licenciaturas()->sync($licenciaturas);

    return response()->json(['status' => 'SUCCESS']);
});

Route::delete('/profesores/{id}', function ($id) {
    try {
        DB::beginTransaction();

        $sinLic = Licenciatura::firstOrCreate(
            ['abreviatura' => 'S/L'],
            ['codigo' => 'C00', 'nombre' => 'Sin licenciatura']
        );

        $sinTutor = Profesor::where('correo', 'sintutor@uaemex.mx')->first();
        if (!$sinTutor) {
            $sinTutor = Profesor::create([
                'nombre' => 'Sin',
                'apellido_paterno' => 'tutor',
                'apellido_materno' => '',
                'correo' => 'sintutor@uaemex.mx',
                'estado' => 'Baja',
            ]);
            $sinTutor->licenciaturas()->attach($sinLic->id);
        }

        if ($id == $sinTutor->id) {
            return response()->json(['status' => 'FAILED', 'error' => 'No se puede eliminar el tutor de respaldo.'], 403);
        }

        Grupo::where('tutor_id', $id)->update(['tutor_id' => $sinTutor->id]);

        $profesor = Profesor::findOrFail($id);
        $profesor->licenciaturas()->detach();
        $profesor->delete();

        DB::commit();
        return response()->json(['status' => 'SUCCESS']);

    } catch (\Exception $e) {
        DB::rollBack();
        return response()->json(['status' => 'FAILED', 'error' => $e->getMessage()], 500);
    }
});

Route::post('/profesores/excel', function (Request $request) {
    $request->validate([
        'file' => 'required|file|mimes:xlsx,xls,csv'
    ]);

    try {
        DB::statement('TRUNCATE TABLE grupo_tutorado, grupos, tutorados, semestres, licenciatura_profesor, profesores CASCADE;');

        DB::beginTransaction();

        $import = new class {};
        $data = \Maatwebsite\Excel\Facades\Excel::toArray($import, $request->file('file'))[0];

        $profesoresCreados = [];

        for ($i = 1; $i < count($data); $i++) {
            $row = $data[$i];

            if (!isset($row[1]) || !isset($row[3]) || trim($row[1]) === '' || trim($row[3]) === '') {
                continue;
            }

            $abreviatura = strtoupper(preg_replace('/\s+/', '', trim($row[0] ?? '')));
            $apPaterno = trim($row[1] ?? '');
            $apMaterno = trim($row[2] ?? '');
            $nombre = trim($row[3] ?? '');
            $correo = trim($row[4] ?? '');
            $estadoVal = strtolower(trim($row[5] ?? ''));

            $estado = ($estadoVal === 'inactivo' || $estadoVal === 'baja' || $estadoVal === 'no') ? 'Inactivo' : 'Activo';

            $key = strtolower($nombre . '|' . $apPaterno . '|' . $apMaterno);

            if (!isset($profesoresCreados[$key])) {
                $profesor = Profesor::create([
                    'nombre' => $nombre,
                    'apellido_paterno' => $apPaterno,
                    'apellido_materno' => $apMaterno,
                    'correo' => $correo,
                    'estado' => $estado,
                ]);
                $profesoresCreados[$key] = $profesor;
            } else {
                $profesor = $profesoresCreados[$key];
            }

            if (!empty($abreviatura)) {
                $lic = Licenciatura::where(DB::raw('UPPER(REPLACE(abreviatura, \' \', \'\'))'), $abreviatura)->first();
                if ($lic) {
                    $profesor->licenciaturas()->syncWithoutDetaching([$lic->id]);
                }
            }
        }

        DB::commit();
        return response()->json(['status' => 'SUCCESS']);

    } catch (\Exception $e) {
        DB::rollBack();
        \Illuminate\Support\Facades\Log::error("Error subiendo Excel Profesores: " . $e->getMessage());
        return response()->json(['status' => 'FAILED', 'error' => $e->getMessage()], 500);
    }
});

// ══════════════════════════════════════════════════════════════════
//  SEMESTRES
// ══════════════════════════════════════════════════════════════════

Route::get('/semestres', function () {
    return response()->json(Semestre::orderBy('clave', 'desc')->get());
});

Route::post('/semestres', function (Request $request) {
    $request->validate([
        'clave' => 'required|string|unique:semestres,clave|max:10',
    ]);

    $semestre = Semestre::create(['clave' => strtoupper(trim($request->clave))]);

    return response()->json(['status' => 'SUCCESS', 'data' => $semestre], 201);
});

Route::put('/semestres/{id}', function (Request $request, $id) {
    $semestre = Semestre::findOrFail($id);

    $request->validate([
        'clave' => 'required|string|max:10|unique:semestres,clave,' . $id,
    ]);

    $semestre->update(['clave' => strtoupper(trim($request->clave))]);

    return response()->json(['status' => 'SUCCESS', 'data' => $semestre]);
});

Route::delete('/semestres/{id}', function ($id) {
    Semestre::destroy($id);
    return response()->json(['status' => 'SUCCESS']);
});

// ══════════════════════════════════════════════════════════════════
//  CARGA MASIVA
// ══════════════════════════════════════════════════════════════════

Route::post('/carga-masiva', [CargaDatosController::class, 'upload']);

// ══════════════════════════════════════════════════════════════════
//  TUTORADOS (alta manual de un alumno)
// ══════════════════════════════════════════════════════════════════

Route::post('/tutorados', function (Request $request) {
    $request->validate([
        'numero_cuenta' => 'required|string',
        'nombre' => 'required|string',
        'apellido_paterno' => 'required|string',
        'apellido_materno' => 'nullable|string',
        'periodo_ingreso' => 'required|string',
        'licenciatura_abreviatura' => 'required|string',
        'tutor_id' => 'required|string',
        'movilidad' => 'required|string',
        'estado_tutorado' => 'required|boolean'
    ]);

    try {
        DB::beginTransaction();

        $licenciatura = Licenciatura::where('abreviatura', $request->licenciatura_abreviatura)->firstOrFail();
        $semestreActual = Semestre::where('tipo', 'actual')->firstOrFail();

        $tutorado = Tutorado::updateOrCreate(
            ['numero_cuenta' => $request->numero_cuenta],
            [
                'nombre' => $request->nombre,
                'apellido_paterno' => $request->apellido_paterno,
                'apellido_materno' => $request->apellido_materno ?? '',
                'periodo_ingreso' => $request->periodo_ingreso,
                'licenciatura_id' => $licenciatura->id,
                'is_active' => $request->estado_tutorado,
            ]
        );

        // CORREGIDO: Crear grupo con licenciatura_id
        $grupo = Grupo::firstOrCreate([
            'semestre_id'     => $semestreActual->id,
            'tutor_id'        => $request->tutor_id,
            'licenciatura_id' => $licenciatura->id,
        ], [
            'estado_tutor' => 'activo',
        ]);

        DB::table('grupo_tutorado')->updateOrInsert(
            ['tutorado_id' => $tutorado->id, 'semestre_id' => $semestreActual->id],
            [
                'grupo_id' => $grupo->id,
                'estado_tutorado' => $request->estado_tutorado ? 'activo' : 'baja',
                'movilidad' => $request->movilidad,
                'created_at' => now(),
                'updated_at' => now(),
            ]
        );

        DB::commit();
        return response()->json(['status' => 'SUCCESS']);
    } catch (\Exception $e) {
        DB::rollBack();
        \Illuminate\Support\Facades\Log::error("Error guardando alumno: " . $e->getMessage());
        return response()->json(['status' => 'FAILED', 'error' => $e->getMessage()], 500);
    }
});

// ══════════════════════════════════════════════════════════════════
//  DASHBOARD DE ASIGNACIONES
//  Incluye ahora licenciatura del grupo en la respuesta.
// ══════════════════════════════════════════════════════════════════

Route::get('/asignaciones/dashboard', function (Request $request) {
    $grupos = Grupo::with([
        'tutor.licenciaturas',
        'licenciatura',
        'tutorados.licenciatura',
    ])->get();

    $tutoresMap = [];

    foreach ($grupos as $grupo) {
        $tutor = $grupo->tutor;
        if (!$tutor) continue;

        $tutorId = $tutor->id;

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

        // NUEVO: incluir la licenciatura del grupo en la respuesta
        $tutoresMap[$tutorId]['grupos'][] = [
            'id'           => $grupo->id,
            'semestre_id'  => $grupo->semestre_id,
            'estado_tutor' => $grupo->estado_tutor,
            'licenciatura' => $grupo->licenciatura ? [
                'id'          => $grupo->licenciatura->id,
                'abreviatura' => $grupo->licenciatura->abreviatura,
                'nombre'      => $grupo->licenciatura->nombre,
            ] : null,
            'tutorados'    => $tutorados,
        ];
    }

    return response()->json([
        'tutores'       => array_values($tutoresMap),
        'licenciaturas' => Licenciatura::all(),
    ]);
});

// ══════════════════════════════════════════════════════════════════
//  REBALANCEO MANUAL (botón "Reasignar")
//  CORREGIDO: Trabaja por (tutor, licenciatura), no por tutor global.
// ══════════════════════════════════════════════════════════════════

Route::post('/asignaciones/rebalanceo-manual', function (Request $request) {
    try {
        DB::beginTransaction();

        $semestreActual = Semestre::where('tipo', 'actual')->first();
        if (!$semestreActual) {
            throw new \Exception('No hay semestre activo configurado.');
        }

        $tutoresActivos = Profesor::with('licenciaturas')->where('estado', 'Activo')->get();
        $todosProfesores = Profesor::with('licenciaturas')->get();
        $licenciaturas = Licenciatura::all();

        $sinLicId = $licenciaturas->first(fn($l) => strtoupper(trim($l->abreviatura)) === 'S/L')?->id ?? 1;
        $tutoresActivosIds = $tutoresActivos->pluck('id')->toArray();

        // ── 1. Crear grupos para tutores activos que aún no tengan ──
        $gruposExistentes = Grupo::where('semestre_id', $semestreActual->id)->get();
        $gMap = [];
        foreach ($gruposExistentes as $g) {
            $gMap[$g->tutor_id . '_' . $g->licenciatura_id] = $g->id;
        }

        foreach ($tutoresActivos as $p) {
            foreach ($p->licenciaturas as $lic) {
                if ($lic->id === $sinLicId) continue;
                $key = $p->id . '_' . $lic->id;
                if (!isset($gMap[$key])) {
                    $g = Grupo::create([
                        'semestre_id'     => $semestreActual->id,
                        'tutor_id'        => $p->id,
                        'licenciatura_id' => $lic->id,
                        'estado_tutor'    => 'activo',
                    ]);
                    $gMap[$key] = $g->id;
                }
            }
        }

        // ── 2. Cargar todas las asignaciones actuales ──
        $pivotData = DB::table('grupo_tutorado')
            ->join('tutorados', 'grupo_tutorado.tutorado_id', '=', 'tutorados.id')
            ->join('grupos', 'grupo_tutorado.grupo_id', '=', 'grupos.id')
            ->where('grupo_tutorado.semestre_id', $semestreActual->id)
            ->where('grupo_tutorado.estado_tutorado', 'activo')
            ->where('tutorados.is_active', true)
            ->select('grupo_tutorado.*', 'tutorados.licenciatura_id as tut_lic_id',
                     'grupos.tutor_id', 'grupos.licenciatura_id as grupo_lic_id')
            ->get();

        $reasignados = 0;

        // ── 3. TUTORES DE BAJA: mover TODOS sus alumnos a 'cambiar' ──
        // Identificar grupos de tutores que NO están activos
        $gruposBaja = Grupo::where('semestre_id', $semestreActual->id)
            ->whereNotIn('tutor_id', $tutoresActivosIds)
            ->pluck('id')
            ->toArray();

        // Pool de redistribución por licenciatura
        $poolRedist = []; // lic_id => [tutorado_id, ...]

        foreach ($pivotData as $row) {
            if (in_array($row->grupo_id, $gruposBaja)) {
                // Cambiar movilidad a 'cambiar' en la BD
                DB::table('grupo_tutorado')
                    ->where('tutorado_id', $row->tutorado_id)
                    ->where('semestre_id', $semestreActual->id)
                    ->update(['movilidad' => 'cambiar', 'updated_at' => now()]);

                $poolRedist[$row->tut_lic_id][] = $row->tutorado_id;
            }
        }

        // Redistribuir alumnos de baja al grupo activo con menor carga de su licenciatura
        // Primero contar capacidades actuales (sin contar los de baja que vamos a mover)
        $capacidades = []; // grupo_id => count
        foreach ($pivotData as $row) {
            if (in_array($row->grupo_id, $gruposBaja)) continue; // excluir los que se van a mover
            $capacidades[$row->grupo_id] = ($capacidades[$row->grupo_id] ?? 0) + 1;
        }
        // Asegurar que los grupos nuevos (vacíos) aparecen con 0
        foreach ($gMap as $gId) {
            if (!isset($capacidades[$gId])) $capacidades[$gId] = 0;
        }

        foreach ($poolRedist as $licId => $tutoradoIds) {
            $gruposLic = [];
            foreach ($tutoresActivos as $p) {
                if (!$p->licenciaturas->contains('id', $licId)) continue;
                $k = $p->id . '_' . $licId;
                if (isset($gMap[$k])) $gruposLic[] = $gMap[$k];
            }
            if (empty($gruposLic)) continue;

            foreach ($tutoradoIds as $tId) {
                // Asignar al grupo con menor carga
                usort($gruposLic, fn($a, $b) => ($capacidades[$a] ?? 0) <=> ($capacidades[$b] ?? 0));
                $destino = $gruposLic[0];

                DB::table('grupo_tutorado')
                    ->where('tutorado_id', $tId)
                    ->where('semestre_id', $semestreActual->id)
                    ->update(['grupo_id' => $destino, 'updated_at' => now()]);

                $capacidades[$destino] = ($capacidades[$destino] ?? 0) + 1;
                $reasignados++;
            }
        }

        // Eliminar grupos de baja que quedaron vacíos
        if (!empty($gruposBaja)) {
            $gruposConAlumnos = DB::table('grupo_tutorado')
                ->where('semestre_id', $semestreActual->id)
                ->whereIn('grupo_id', $gruposBaja)
                ->pluck('grupo_id')->unique()->toArray();

            Grupo::whereIn('id', $gruposBaja)
                 ->whereNotIn('id', $gruposConAlumnos)
                 ->delete();
        }

        // ── 4. ROBO JUSTO por licenciatura ──
        // Recargar datos después de los movimientos de baja
        $pivotFresh = DB::table('grupo_tutorado')
            ->join('tutorados', 'grupo_tutorado.tutorado_id', '=', 'tutorados.id')
            ->join('grupos', 'grupo_tutorado.grupo_id', '=', 'grupos.id')
            ->where('grupo_tutorado.semestre_id', $semestreActual->id)
            ->where('grupo_tutorado.estado_tutorado', 'activo')
            ->where('tutorados.is_active', true)
            ->select('grupo_tutorado.*', 'tutorados.licenciatura_id as tut_lic_id',
                     'grupos.tutor_id', 'grupos.licenciatura_id as grupo_lic_id')
            ->get();

        foreach ($licenciaturas as $lic) {
            if ($lic->id === $sinLicId) continue;

            // Grupos activos de esta licenciatura
            $gruposLic = [];
            foreach ($tutoresActivos as $p) {
                if (!$p->licenciaturas->contains('id', $lic->id)) continue;
                $k = $p->id . '_' . $lic->id;
                if (isset($gMap[$k])) $gruposLic[] = $gMap[$k];
            }
            if (count($gruposLic) <= 1) continue;

            // Contar y recopilar movibles
            $cap = array_fill_keys($gruposLic, 0);
            $movibles = array_fill_keys($gruposLic, []);

            foreach ($pivotFresh as $row) {
                if (!in_array($row->grupo_id, $gruposLic)) continue;
                $cap[$row->grupo_id]++;

                if ($row->movilidad === 'nuevo_ingreso') {
                    $movibles[$row->grupo_id][] = ['id' => $row->tutorado_id, 'p' => 0];
                } elseif ($row->movilidad === 'cambiar') {
                    $movibles[$row->grupo_id][] = ['id' => $row->tutorado_id, 'p' => 1];
                }
                // no_cambiar: NUNCA se mueve
            }

            foreach ($movibles as &$lst) usort($lst, fn($a, $b) => $a['p'] <=> $b['p']);
            unset($lst);

            // Robo justo 1 a 1 hasta que max - min <= 1
            $locked = [];
            for ($it = 0; $it < 5000; $it++) {
                $mnG = null; $mnC = PHP_INT_MAX;
                $mxG = null; $mxC = -1;

                foreach ($cap as $g => $c) {
                    if ($c < $mnC) { $mnC = $c; $mnG = $g; }
                    if ($c > $mxC && !in_array($g, $locked)) { $mxC = $c; $mxG = $g; }
                }

                if (!$mxG || ($mxC - $mnC) <= 1) break;

                if (!empty($movibles[$mxG])) {
                    $cand = array_shift($movibles[$mxG]);

                    DB::table('grupo_tutorado')
                        ->where('tutorado_id', $cand['id'])
                        ->where('semestre_id', $semestreActual->id)
                        ->update(['grupo_id' => $mnG, 'updated_at' => now()]);

                    $cap[$mxG]--; $cap[$mnG]++;
                    $movibles[$mnG][] = $cand;
                    $reasignados++;
                } else {
                    $locked[] = $mxG;
                }
            }
        }

        // Limpiar grupos vacíos restantes
        $gruposConAlumnos = DB::table('grupo_tutorado')
            ->where('semestre_id', $semestreActual->id)
            ->pluck('grupo_id')->unique()->toArray();
        Grupo::where('semestre_id', $semestreActual->id)
             ->whereNotIn('id', $gruposConAlumnos)
             ->delete();

        DB::commit();
        return response()->json([
            'status' => 'SUCCESS',
            'message' => "Rebalanceo completado. Se reubicaron $reasignados alumnos."
        ]);

    } catch (\Exception $e) {
        DB::rollBack();
        return response()->json(['status' => 'FAILED', 'error' => $e->getMessage()], 500);
    }
});