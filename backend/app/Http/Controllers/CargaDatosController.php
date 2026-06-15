<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Services\CargaTutoriasService;

class CargaDatosController extends Controller
{
    protected $cargaService;

    public function __construct(CargaTutoriasService $cargaService)
    {
        $this->cargaService = $cargaService;
    }

public function upload(Request $request)
    {
        set_time_limit(0);
        
        $request->validate([
            'semestre_clave' => 'required|string|max:10', // Ej: 2024A
            'file_nuevos'    => 'required|file|mimes:xlsx,xls,csv',
            'file_historico' => 'required|file|mimes:xlsx,xls,csv',
            'file_propuesta' => 'required|file|mimes:xlsx,xls,csv',
        ]);

        $resultado = $this->cargaService->procesarCargaMasiva(
            $request->file('file_nuevos'),
            $request->file('file_historico'),
            $request->file('file_propuesta'),
            $request->input('semestre_clave') // Pasamos la clave al servicio
        );

        if ($resultado['success']) {
            return response()->json(['message' => $resultado['message']], 200);
        }

        return response()->json(['error' => $resultado['error']], 422);
    }
}