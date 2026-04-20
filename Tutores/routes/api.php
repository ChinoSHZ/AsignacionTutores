<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Hash;
use App\Models\User;
use App\Models\Licenciatura;
use App\Models\Profesor;
use PragmaRX\Google2FA\Google2FA;
use Illuminate\Support\Facades\Response;
use Illuminate\Support\Facades\Storage;

Route::post('/login', function (Request $request) {
    $request->validate([
        'email' => 'required', // Se quita regla 'email' para permitir el texto "admin"
        'password' => 'required',
    ]);

    // Verificar si la base de datos no tiene usuarios 
    $userCount = User::count();

    if ($userCount === 0 && $request->email === 'admin' && $request->password === 'admin') {
        // Crear el usuario administrador inicial para permitir el acceso 
        $user = User::create([
            'name' => 'Administrador de Sistema',
            'email' => 'admin@admin.com', // Email por defecto interno
            'password' => Hash::make('admin'),
            'mfa_enabled' => false
        ]);

        return response()->json([
            'status' => 'SUCCESS',
            'token' => $user->createToken('auth_token')->plainTextToken,
            'first_login' => true // Bandera para el frontend
        ], 200);
    }

    // Lógica existente para usuarios normales
    $user = User::where('email', $request->email)->first();

    if (!$user || !Hash::check($request->password, $user->password)) {
        return response()->json(['message' => 'Unauthorized'], 401);
    }

    return response()->json([
        'status' => 'SUCCESS',
        'token' => $user->createToken('auth_token')->plainTextToken,
        'first_login' => false
    ], 200);
});

Route::middleware('auth:sanctum')->post('/mfa/verify', function (Request $request) {
    $request->validate([
        'mfa_code' => 'required|string'
    ]);

    $user = $request->user();
    $google2fa = new Google2FA();
    
    $valid = $google2fa->verifyKey($user->mfa_secret, $request->input('mfa_code'));

    if ($valid) {
        $user->tokens()->where('name', 'mfa_temp')->delete();
        return response()->json([
            'status' => 'SUCCESS',
            'token' => $user->createToken('auth_token')->plainTextToken
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

    // Generar URL para el QR
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

    // Generamos un token temporal sin pedir contraseña
    return response()->json([
        'status' => 'MFA_REQUIRED',
        'temp_token' => $user->createToken('mfa_temp')->plainTextToken
    ], 200);
});

Route::middleware('auth:sanctum')->post('/mfa/verify', function (Request $request) {
    $request->validate([
        'mfa_code' => 'required|string',
        'new_password' => 'nullable|string|min:6' // Parámetro opcional para actualización
    ]);

    $user = $request->user();
    $google2fa = new \PragmaRX\Google2FA\Google2FA();
    
    $valid = $google2fa->verifyKey($user->mfa_secret, $request->mfa_code);

    if ($valid) {
        // Si la intención es actualizar contraseña
        if ($request->has('new_password')) {
            $user->password = Hash::make($request->new_password);
            $user->save();
            $user->tokens()->delete(); // Seguridad: Revoca todos los tokens tras cambio de clave
            return response()->json(['status' => 'SUCCESS', 'message' => 'Password updated']);
        }

        // Flujo normal de login
        $user->tokens()->where('name', 'mfa_temp')->delete();
        return response()->json([
            'status' => 'SUCCESS', 
            'token' => $user->createToken('auth_token')->plainTextToken
        ], 200);
    }

    return response()->json(['status' => 'FAILED'], 401);
});

// Endpoint para obtener todas las licenciaturas
Route::get('/licenciaturas', function () {
    return response()->json(Licenciatura::all());
});

// Endpoint para obtener todos los profesores con sus licenciaturas (Muchos a Muchos)
Route::get('/profesores', function () {
    // Laravel descifrará los campos 'encrypted' automáticamente
    return response()->json(Profesor::with('licenciaturas')->get());
});

// RUTA PARA EXPORTAR (Descargar)
Route::get('/backup/export', function (Request $request) {
    $filename = $request->query('filename', 'respaldo.sql');
    $path = storage_path('app/' . $filename);
    
    // 1. Generar el dump DENTRO del contenedor Docker usando variables de entorno
    $dockerDumpCmd = "docker exec -e PGPASSWORD=PasswordSeguro123 tutoria_db_final pg_dump -U admin_tutoria -d tutoria_db -F c -f /tmp/{$filename}";
    exec($dockerDumpCmd);

    // 2. Copiar el archivo desde el contenedor hacia la carpeta de Laravel
    $dockerCpCmd = "docker cp tutoria_db_final:/tmp/{$filename} \"{$path}\"";
    exec($dockerCpCmd);

    if (file_exists($path)) {
        return Response::download($path, $filename)->deleteFileAfterSend(true);
    }

    return response()->json(['error' => 'No se pudo generar el respaldo'], 500);
});

// RUTA PARA IMPORTAR (Restaurar)
Route::post('/backup/import', function (Request $request) {
    $request->validate([
        'backup_file' => 'required|file'
    ]);

    $file = $request->file('backup_file');
    $path = $file->storeAs('backups', 'restore.sql', 'local');
    
    // Obtener la ruta absoluta real generada por el disco 'local'
    $fullPath = Storage::disk('local')->path($path);

    // 1. Detección Inteligente del formato del archivo
    $header = file_get_contents($fullPath, false, null, 0, 5);
    $isCustomFormat = ($header === 'PGDMP');

    // 2. Copiar al contenedor Docker
    $dockerCpCmd = "docker cp \"{$fullPath}\" tutoria_db_final:/tmp/restore.sql";
    exec($dockerCpCmd);

    // 3. Limpiar la base de datos actual
    $dockerCleanCmd = "docker exec -e PGPASSWORD=PasswordSeguro123 tutoria_db_final psql -U admin_tutoria -d tutoria_db -c \"DROP SCHEMA public CASCADE; CREATE SCHEMA public;\"";
    exec($dockerCleanCmd);

    // 4. Ejecutar restauración según el formato detectado
    if ($isCustomFormat) {
        $restoreCmd = "docker exec -e PGPASSWORD=PasswordSeguro123 tutoria_db_final pg_restore -U admin_tutoria -d tutoria_db -O -x /tmp/restore.sql 2>&1";
    } else {
        $restoreCmd = "docker exec -e PGPASSWORD=PasswordSeguro123 tutoria_db_final psql -U admin_tutoria -d tutoria_db -f /tmp/restore.sql 2>&1";
    }
    
    exec($restoreCmd, $output, $returnVar);

    // 5. Limpieza de temporales
    Storage::disk('local')->delete($path);
    exec("docker exec tutoria_db_final rm /tmp/restore.sql");

    // Si es exitoso
    if (in_array($returnVar, [0, 1, 3])) {
        return response()->json(['status' => 'SUCCESS']);
    }

    // Guardar error en log en caso de fallo
    \Illuminate\Support\Facades\Log::error("Error restaurando DB:\n" . implode("\n", $output));
    return response()->json(['status' => 'FAILED'], 500);
});