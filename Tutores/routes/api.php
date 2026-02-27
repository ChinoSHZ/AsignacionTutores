<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;

/*
|--------------------------------------------------------------------------
| API Routes - Monitor de Tutorías (Shiha)
|--------------------------------------------------------------------------
*/

// 1. Endpoint para llenar el ComboBox en Flutter
Route::get('/tablas', function () {
    try {
        // PostgreSQL es estricto con los nombres. 
        // Usamos LOWER() para asegurar que encuentre el esquema sin importar si hay variaciones.
        $tablas = DB::select("SELECT table_name 
                              FROM information_schema.tables 
                              WHERE LOWER(table_schema) = LOWER('tutoria') 
                              AND table_type = 'BASE TABLE'
                              ORDER BY table_name ASC");
        
        return response()->json($tablas);
    } catch (\Exception $e) {
        return response()->json(['error' => 'Error al listar tablas: ' . $e->getMessage()], 500);
    }
});

// 2. Endpoint para llenar el DataTable en Flutter
Route::get('/datos/{tabla}', function ($tabla) {
    try {
        // Seguridad: Solo permitir caracteres alfanuméricos y guiones bajos
        if (!preg_match('/^[a-zA-Z0-9_]+$/', $tabla)) {
            return response()->json(['error' => 'Nombre de tabla no válido'], 400);
        }

        // Importante: En PostgreSQL, si la tabla está en un esquema que no es 'public',
        // debemos usar la notación de punto encerrada en comillas si hay mayúsculas,
        // o simplemente "esquema"."tabla".
        $registros = DB::table("tutoria.$tabla")->get();

        return response()->json($registros);
    } catch (\Exception $e) {
        return response()->json(['error' => "Error en tabla '$tabla': " . $e->getMessage()], 500);
    }
});