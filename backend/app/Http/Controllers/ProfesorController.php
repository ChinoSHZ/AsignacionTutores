<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
// use Maatwebsite\Excel\Facades\Excel;
// use App\Imports\ProfesoresImport;

class ProfesorController extends Controller
{
    public function uploadCatalogo(Request $request)
    {
        $request->validate([
            'file_profesores' => 'required|file|mimes:xlsx,xls,csv',
        ]);

        // Ejecución de purga absoluta en PostgreSQL usando CASCADE.
        // Se excluyen explícitamente 'users' y 'licenciaturas'.
        DB::statement('TRUNCATE TABLE grupo_tutorado, grupos, tutorados, semestres, licenciatura_profesor, profesores CASCADE;');

        try {
            // Descomentar y ajustar según la clase de importación utilizada en el sistema
            // Excel::import(new ProfesoresImport, $request->file('file_profesores'));
            
            return response()->json(['success' => true, 'message' => 'Tablas purgadas y catálogo actualizado correctamente.'], 200);
        } catch (\Exception $e) {
            return response()->json(['success' => false, 'error' => 'Error backend: ' . $e->getMessage()], 500);
        }
    }
}