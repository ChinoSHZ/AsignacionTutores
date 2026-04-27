<?php

namespace App\Imports;

use App\Models\Tutorado;
use App\Models\Profesor;
use App\Models\Grupo;
use App\Models\Semestre;
use Illuminate\Support\Facades\DB;
use Maatwebsite\Excel\Row;
use Maatwebsite\Excel\Concerns\OnEachRow;
use Maatwebsite\Excel\Concerns\WithHeadingRow;

/**
 * Columnas del Excel (keys tras WithHeadingRow):
 *   numero_de_cuenta, nombre_del_tutorado, apellido_paterno_tutorado,
 *   apellido_materno_tutorado, nombre_del_tutor, apellido_paterno_tutor,
 *   apellido_materno_tutor, estado_cambiar_no_cambiar
 *
 * PropuestaImport tiene MÁXIMA PRIORIDAD: sobreescribe lo que hayan
 * establecido NuevosIngresosImport e HistoricoImport.
 */
class PropuestaImport implements OnEachRow, WithHeadingRow
{
    private $semestreActual;
    private $tutores;

    public function __construct()
    {
        $this->semestreActual = Semestre::actual();
        $this->tutores        = Profesor::all();
    }

    private function limpiar(?string $texto): string
    {
        if (!$texto) return '';
        $busqueda  = ['á','é','í','ó','ú','Á','É','Í','Ó','Ú','ñ','Ñ'];
        $reemplazo = ['a','e','i','o','u','A','E','I','O','U','n','N'];
        $texto = str_replace($busqueda, $reemplazo, $texto);
        return strtoupper(preg_replace('/\s+/', '', $texto));
    }

    public function onRow(Row $row): void
    {
        $fila   = $row->toArray();
        $cuenta = trim((string)($fila['numero_de_cuenta'] ?? ''));
        if (!$cuenta || !$this->semestreActual) return;

        // Buscar tutorado en DB (ya debe existir tras los imports anteriores)
        $tutorado = Tutorado::where('numero_cuenta', $cuenta)->first();
        if (!$tutorado) return;

        // Determinar movilidad
        // La columna es: 'Estado (Cambiar, no cambiar)' → key: 'estado_cambiar_no_cambiar'
        $estado    = strtoupper(trim($fila['estado_cambiar_no_cambiar'] ?? ''));
        $movilidad = (str_contains($estado, 'CAMBIAR') && !str_contains($estado, 'NO'))
            ? 'cambiar'
            : 'no_cambiar';

        // Buscar tutor
        $nombreExc  = $this->limpiar($fila['nombre_del_tutor'] ?? '');
        $paternoExc = $this->limpiar($fila['apellido_paterno_tutor'] ?? '');
        if (!$nombreExc || !$paternoExc) return;

        $profesor = $this->tutores->first(fn($p) =>
            $this->limpiar($p->nombre) === $nombreExc &&
            $this->limpiar($p->apellido_paterno) === $paternoExc
        );
        if (!$profesor) return;

        $grupo = Grupo::firstOrCreate([
            'semestre_id' => $this->semestreActual->id,
            'tutor_id'    => $profesor->id,
        ]);

        // Sobreescribir asignación con la propuesta del coordinador
        DB::table('grupo_tutorado')->updateOrInsert(
            ['tutorado_id' => $tutorado->id, 'semestre_id' => $this->semestreActual->id],
            [
                'grupo_id'   => $grupo->id,
                'movilidad'  => $movilidad,
                'updated_at' => now(),
            ]
        );
    }
}