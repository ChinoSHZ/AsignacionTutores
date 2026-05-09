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

Route::get('/licenciaturas', function () {
    return response()->json(App\Models\Licenciatura::all());
});

Route::post('/licenciaturas', function (Illuminate\Http\Request $request) {
    $request->validate([
        'abreviatura' => 'required|string',
        'nombre' => 'required|string',
    ]);
    
    $last = App\Models\Licenciatura::orderBy('id', 'desc')->first();
    $nextId = $last ? $last->id + 1 : 1;
    $codigo = 'C' . str_pad($nextId, 2, '0', STR_PAD_LEFT);

    $licenciatura = App\Models\Licenciatura::create([
        'codigo' => $codigo,
        'abreviatura' => $request->abreviatura,
        'nombre' => $request->nombre
    ]);
    return response()->json(['status' => 'SUCCESS', 'data' => $licenciatura]);
});

Route::put('/licenciaturas/{id}', function (Illuminate\Http\Request $request, $id) {
    $licenciatura = App\Models\Licenciatura::findOrFail($id);
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
        \Illuminate\Support\Facades\DB::beginTransaction();

        // 1. Asegurar que existe la licenciatura comodín
        $sinLic = App\Models\Licenciatura::firstOrCreate(
            ['abreviatura' => 'S/L'],
            ['codigo' => 'C00', 'nombre' => 'Sin licenciatura']
        );

        // Protección: Evitar que alguien borre la licenciatura comodín por error
        if ($id == $sinLic->id) {
            return response()->json(['status' => 'FAILED', 'error' => 'No se puede eliminar la categoría de respaldo.'], 403);
        }

        // 2. Reasignar Alumnos (Tutorados) que tengan esta licenciatura
        App\Models\Tutorado::where('licenciatura_id', $id)->update(['licenciatura_id' => $sinLic->id]);

        // 3. Reasignar Profesores
        // Buscamos a los profesores que tienen la licenciatura que se va a borrar
        $profesores = App\Models\Profesor::whereHas('licenciaturas', function ($query) use ($id) {
            $query->where('licenciaturas.id', $id);
        })->get();

        foreach ($profesores as $profesor) {
            // Le quitamos la licenciatura que se va a eliminar
            $profesor->licenciaturas()->detach($id);

            // Verificamos si se quedó sin ninguna licenciatura en absoluto
            if ($profesor->licenciaturas()->count() === 0) {
                // Le asignamos la licenciatura comodín
                $profesor->licenciaturas()->attach($sinLic->id);
            }
        }

        // 4. Finalmente, procedemos a borrar la licenciatura original
        App\Models\Licenciatura::destroy($id);

        \Illuminate\Support\Facades\DB::commit();
        return response()->json(['status' => 'SUCCESS']);
        
    } catch (\Exception $e) {
        \Illuminate\Support\Facades\DB::rollBack();
        return response()->json(['status' => 'FAILED', 'error' => $e->getMessage()], 500);
    }
});

Route::get('/profesores', function () {
    return response()->json(Profesor::with('licenciaturas')->get());
});

Route::post('/profesores', function (Illuminate\Http\Request $request) {
    $request->validate([
        'nombre' => 'required|string',
        'apellido_paterno' => 'required|string',
        'apellido_materno' => 'nullable|string',
        'correo' => 'nullable|email', 
        'carreras' => 'required|array',
        'estado' => 'required|string',
    ]);

    $profesor = App\Models\Profesor::create([
        'nombre' => $request->nombre,
        'apellido_paterno' => $request->apellido_paterno,
        'apellido_materno' => $request->apellido_materno ?? '',
        'correo' => $request->correo ?? '', 
        'estado' => $request->estado,
    ]);

    $licenciaturas = App\Models\Licenciatura::whereIn('abreviatura', $request->carreras)->pluck('id');
    $profesor->licenciaturas()->sync($licenciaturas);

    return response()->json(['status' => 'SUCCESS']);
});

Route::put('/profesores/{id}', function (Illuminate\Http\Request $request, $id) {
    $profesor = App\Models\Profesor::findOrFail($id);
    
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

    $licenciaturas = App\Models\Licenciatura::whereIn('abreviatura', $request->carreras)->pluck('id');
    $profesor->licenciaturas()->sync($licenciaturas);

    return response()->json(['status' => 'SUCCESS']);
});

Route::delete('/profesores/{id}', function ($id) {
    try {
        \Illuminate\Support\Facades\DB::beginTransaction();

        $sinLic = App\Models\Licenciatura::firstOrCreate(
            ['abreviatura' => 'S/L'],
            ['codigo' => 'C00', 'nombre' => 'Sin licenciatura']
        );

        $sinTutor = App\Models\Profesor::where('correo', 'sintutor@uaemex.mx')->first();
        if (!$sinTutor) {
            $sinTutor = App\Models\Profesor::create([
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

        App\Models\Grupo::where('tutor_id', $id)->update(['tutor_id' => $sinTutor->id]);

        $profesor = App\Models\Profesor::findOrFail($id);
        $profesor->licenciaturas()->detach();
        $profesor->delete();

        \Illuminate\Support\Facades\DB::commit();
        return response()->json(['status' => 'SUCCESS']);
        
    } catch (\Exception $e) {
        \Illuminate\Support\Facades\DB::rollBack();
        return response()->json(['status' => 'FAILED', 'error' => $e->getMessage()], 500);
    }
});

Route::post('/profesores/excel', function (Request $request) {
    $request->validate([
        'file' => 'required|file|mimes:xlsx,xls,csv'
    ]);

    try {
        DB::beginTransaction();

        Profesor::query()->delete();

        $import = new class {};
        $data = \Maatwebsite\Excel\Facades\Excel::toArray($import, $request->file('file'))[0];

        $profesoresCreados = [];

        for ($i = 1; $i < count($data); $i++) {
            $row = $data[$i];

            if (!isset($row[1]) || !isset($row[3]) || trim($row[1]) === '' || trim($row[3]) === '') {
                continue;
            }

            $abreviatura = trim($row[0] ?? '');
            $apPaterno = trim($row[1] ?? '');
            $apMaterno = trim($row[2] ?? '');
            $nombre = trim($row[3] ?? '');
            $correo = trim($row[4] ?? '');
            $estadoVal = trim($row[5] ?? '');

            $estado = empty($estadoVal) ? 'Activo' : 'Inactivo';

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
                $lic = Licenciatura::where('abreviatura', $abreviatura)->first();
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

Route::get('/semestres', function () {
    return response()->json(
        Semestre::orderBy('clave', 'desc')->get()
    );
});
 
Route::post('/semestres', function (Illuminate\Http\Request $request) {
    $request->validate([
        'clave' => 'required|string|unique:semestres,clave|max:10',
    ]);
 
    $semestre = Semestre::create(['clave' => strtoupper(trim($request->clave))]);
 
    return response()->json(['status' => 'SUCCESS', 'data' => $semestre], 201);
});
 
Route::put('/semestres/{id}', function (Illuminate\Http\Request $request, $id) {
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

Route::get('/semestres', [SemestreController::class, 'index']);

Route::post('/carga-masiva', [CargaDatosController::class, 'upload']);

Route::get('/asignaciones/dashboard', function(Request $request) {
    $filtroSemestre = $request->query('semestre', 'Todos');

    $query = Grupo::with([
        'tutor.licenciaturas',
        'tutorados.licenciatura',
    ]);

    if ($filtroSemestre !== 'Todos') {
        $semestreObj = Semestre::where('clave', $filtroSemestre)->first();
        if ($semestreObj) {
            $query->where('semestre_id', $semestreObj->id);
        } else {
            return response()->json([
                'semestres'     => Semestre::all(),
                'tutores'       => [],
                'licenciaturas' => Licenciatura::all(),
            ]);
        }
    }

    $grupos = $query->get();

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

        $tutoresMap[$tutorId]['grupos'][] = [
            'id'           => $grupo->id,
            'semestre_id'  => $grupo->semestre_id,
            'estado_tutor' => $grupo->estado_tutor,
            'tutorados'    => $tutorados,
        ];
    }

    return response()->json([
        'semestres'     => Semestre::all(),
        'tutores'       => array_values($tutoresMap),
        'licenciaturas' => Licenciatura::all(),
    ]);
});


Route::get('/usuarios', function () {
    return response()->json(\App\Models\User::select('id', 'name', 'email', 'mfa_enabled')->get());
});

Route::delete('/usuarios/{id}', function ($id) {
    \App\Models\User::destroy($id);
    return response()->json(['status' => 'SUCCESS']);
});

Route::post('/tutorados', function (Illuminate\Http\Request $request) {
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

        $grupo = Grupo::firstOrCreate([
            'semestre_id' => $semestreActual->id,
            'tutor_id' => $request->tutor_id,
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