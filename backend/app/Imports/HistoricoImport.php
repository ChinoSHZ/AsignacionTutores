<?php

namespace App\Imports;

use App\Models\Tutorado;
use App\Models\Profesor;
use App\Models\Grupo;
use App\Models\Licenciatura;
use App\Models\Semestre;
use Illuminate\Support\Facades\DB;
use Maatwebsite\Excel\Row;
use Maatwebsite\Excel\Concerns\OnEachRow;
use Maatwebsite\Excel\Concerns\WithHeadingRow;

/**
 * Columnas del Excel (keys tras WithHeadingRow):
 *   licenciatura, numero_de_cuenta, nombre_del_tutorado,
 *   apellido_paterno_tutorado, apellido_materno_tutorado, periodo_ingreso,
 *   nombre_del_tutor, apellido_paterno_tutor, apellido_materno_tutor
 */
class HistoricoImport implements OnEachRow, WithHeadingRow
{
    private $semestreActual;
    private $licenciaturas;
    private $tutores;

    public function __construct()
    {
        $this->semestreActual = Semestre::actual();
        $this->licenciaturas  = Licenciatura::all();
        // Cargar DESPUÉS de NuevosIngresosImport para tener tutorados frescos.
        // Profesor::all() descifra 'encrypted' automáticamente.
        $this->tutores = Profesor::all();
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

        // 1. Insertar tutorado si no existe (alumnos de reingreso pueden no estar aún)
        $licId = $this->licenciaturas
            ->firstWhere('abreviatura', trim($fila['licenciatura'] ?? ''))?->id ?? 1;

        $tutorado = Tutorado::firstOrCreate(
            ['numero_cuenta' => $cuenta],
            [
                'nombre'           => trim($fila['nombre_del_tutorado'] ?? ''),
                'apellido_paterno' => trim($fila['apellido_paterno_tutorado'] ?? ''),
                'apellido_materno' => trim($fila['apellido_materno_tutorado'] ?? null),
                'periodo_ingreso'  => trim($fila['periodo_ingreso'] ?? ''), // <-- columna correcta
                'licenciatura_id'  => $licId,
                'is_active'        => true,
            ]
        );

        // 2. Buscar tutor
        $nombreExc  = $this->limpiar($fila['nombre_del_tutor'] ?? '');
        $paternoExc = $this->limpiar($fila['apellido_paterno_tutor'] ?? '');
        if (!$nombreExc || !$paternoExc) return;

        $profesor = $this->tutores->first(fn($p) =>
            $this->limpiar($p->nombre) === $nombreExc &&
            $this->limpiar($p->apellido_paterno) === $paternoExc
        );
        if (!$profesor) return;

        // 3. Crear grupo si no existe
        $grupo = Grupo::firstOrCreate([
            'semestre_id' => $this->semestreActual->id,
            'tutor_id'    => $profesor->id,
        ]);

        // 4. Asignar (solo si no tiene ya asignación en este semestre)
        DB::table('grupo_tutorado')->updateOrInsert(
            ['tutorado_id' => $tutorado->id, 'semestre_id' => $this->semestreActual->id],
            [
                'grupo_id'        => $grupo->id,
                'estado_tutorado' => 'activo',
                'movilidad'       => 'no_cambiar',
                'created_at'      => now(),
                'updated_at'      => now(),
            ]
        );
    }
}