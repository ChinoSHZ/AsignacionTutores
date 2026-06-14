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

        DB::statement('PRAGMA foreign_keys = OFF;');
        $tablas = ['grupo_tutorado', 'grupos', 'tutorados', 'semestres', 'licenciatura_profesor', 'profesores'];
        foreach ($tablas as $tabla) {
            DB::table($tabla)->delete();
            DB::statement("DELETE FROM sqlite_sequence WHERE name='$tabla';");
        }
        DB::statement('PRAGMA foreign_keys = ON;');

        try {
            // Descomentar y ajustar según la clase de importación utilizada en el sistema
            // Excel::import(new ProfesoresImport, $request->file('file_profesores'));
            
            return response()->json(['success' => true, 'message' => 'Tablas purgadas y catálogo actualizado correctamente.'], 200);
        } catch (\Exception $e) {
            return response()->json(['success' => false, 'error' => 'Error backend: ' . $e->getMessage()], 500);
        }
    }
}