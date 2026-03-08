<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Facades\DB;

/*
|--------------------------------------------------------------------------
| API Routes - Monitor de Tutorías (Shiha)
|--------------------------------------------------------------------------
*/

Route::get('/tablas', function () {
    try {
        $tablas = DB::select("SELECT table_name 
                              FROM information_schema.tables 
                              WHERE LOWER(table_schema) = 'tutoria' 
                              AND table_type = 'BASE TABLE'
                              ORDER BY table_name ASC");
        return response()->json($tablas);
    } catch (\Exception $e) {
        return response()->json(['error' => $e->getMessage()], 500);
    }
});

Route::get('/datos/{tabla}', function ($tabla) {
    try {
        if (!preg_match('/^[a-zA-Z0-9_]+$/', $tabla)) {
            return response()->json(['error' => 'Nombre no válido'], 400);
        }

        $tablaLower = strtolower($tabla);

        // Si es GRUPO o BORRADOR, forzamos los JOINs con el esquema 'tutoria'
        if ($tablaLower === 'grupo' || $tablaLower === 'borrador') {
            $registros = DB::table("tutoria.$tablaLower as t")
                ->join("tutoria.profesores as p", "t.correo_profe", "=", "p.correo")
                ->join("tutoria.alumnos as a", "t.num_cuenta", "=", "a.num_cuenta")
                ->select(
                    "t.*", 
                    "p.nombre as nombre_profesor", 
                    "a.nombre as nombre_alumno"
                )
                ->get();
        } else {
            $registros = DB::table("tutoria.$tablaLower")->get();
        }

        return response()->json($registros);

    } catch (\Exception $e) {
        // MUY IMPORTANTE: Este mensaje te dirá exactamente qué falta en tu base de datos
        return response()->json([
            'status' => 'error',
            'message' => 'Error en la base de datos',
            'sql_error' => $e->getMessage()
        ], 500);
    }
});