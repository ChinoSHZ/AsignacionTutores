<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Hash;
use App\Models\User;
use App\Models\Licenciatura;
use App\Models\Profesor;
use PragmaRX\Google2FA\Google2FA;

Route::post('/login', function (Request $request) {
    $request->validate([
        'email' => 'required|email',
        'password' => 'required',
    ]);

    $user = User::where('email', $request->email)->first();

    if (!$user || !Hash::check($request->password, $user->password)) {
        return response()->json(['message' => 'Unauthorized'], 401);
    }

    // Se elimina el bloque 'if ($user->mfa_enabled)' para omitir el paso de MFA
    // y entregar el token de acceso completo (auth_token) de inmediato.
    return response()->json([
        'status' => 'SUCCESS',
        'token' => $user->createToken('auth_token')->plainTextToken
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