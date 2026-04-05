<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\Hash;
use App\Models\User;
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

    if ($user->mfa_enabled) {
        return response()->json([
            'status' => 'MFA_REQUIRED',
            'temp_token' => $user->createToken('mfa_temp')->plainTextToken
        ], 200);
    }

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