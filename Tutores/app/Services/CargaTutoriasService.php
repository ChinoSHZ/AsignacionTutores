<?php

namespace App\Services;

use App\Imports\NuevosIngresosImport;
use App\Imports\HistoricoImport;
use App\Imports\PropuestaImport;
use App\Models\Semestre; // Asegúrate de importar el modelo
use Illuminate\Support\Facades\DB;
use Maatwebsite\Excel\Facades\Excel;
use Exception;

class CargaTutoriasService
{
    public function procesarCargaMasiva($fileNuevos, $fileHistorico, $filePropuesta, $claveSemestre)
    {
        try {
            DB::transaction(function () use ($fileNuevos, $fileHistorico, $filePropuesta, $claveSemestre) {
                
                // ── MAGIA DE SEMESTRES AUTOMÁTICA ──
                $semestreActual = Semestre::actual();
                
                if (!$semestreActual) {
                    // 1. Es la primera vez que se usa el sistema en la historia
                    Semestre::create(['clave' => $claveSemestre, 'tipo' => 'actual']);
                } elseif ($semestreActual->clave !== $claveSemestre) {
                    // 2. Es un nuevo ciclo escolar, activamos la Ventana Deslizante
                    Semestre::avanzar($claveSemestre);
                }
                // Si la clave es la misma, simplemente actualiza los datos del semestre actual sin mover la ventana.

                // ── CARGA DE EXCEL ──
                if ($fileNuevos) Excel::import(new NuevosIngresosImport, $fileNuevos);
                if ($fileHistorico) Excel::import(new HistoricoImport, $fileHistorico);
                if ($filePropuesta) Excel::import(new PropuestaImport, $filePropuesta);
                
            });

            return ['success' => true, 'message' => 'Carga de datos completada correctamente.'];

        } catch (\Throwable $e) {
            return ['success' => false, 'error' => 'Error backend: ' . $e->getMessage() . ' (Línea ' . $e->getLine() . ')'];
        }
    }
}