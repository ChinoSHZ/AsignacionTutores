<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Profesor;
use App\Models\Licenciatura;

class ProfesorSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // Datos extraídos del archivo CatalogoProfesores
        $profesores = [
            ['lic' => 'ICI', 'ap' => 'ALBITER', 'am' => 'BERNAL', 'nom' => 'VLADIMIR ANGEL'],
            ['lic' => 'ICI', 'ap' => 'ALBITER', 'am' => 'RODRIGUEZ', 'nom' => 'ANGEL'],
            ['lic' => 'ICI', 'ap' => 'BECERRIL', 'am' => 'VILCHIS', 'nom' => 'FRANCISCO'],
            ['lic' => 'ICI', 'ap' => 'DELGADO', 'am' => 'HERNANDEZ', 'nom' => 'DAVID JOAQUIN'],
            ['lic' => 'ICI', 'ap' => 'DIAZ', 'am' => 'CAMACHO', 'nom' => 'SERGIO ALEJANDRO'],
            ['lic' => 'ICI', 'ap' => 'DIAZ', 'am' => 'MENDIETA', 'nom' => 'RAQUEL ALEJANDRA'],
            ['lic' => 'ICI', 'ap' => 'DOMINGUEZ', 'am' => 'ALAMILLA', 'nom' => 'VERONICA'],
            ['lic' => 'ICI', 'ap' => 'GUADARRAMA', 'am' => 'FONSECA', 'nom' => 'JUAN MANUEL'],
            ['lic' => 'ICI', 'ap' => 'GARCIA', 'am' => 'PULIDO', 'nom' => 'DAURY'],
            ['lic' => 'ICI', 'ap' => 'GUTIERREZ', 'am' => 'CALZADA', 'nom' => 'DAVID'],
            ['lic' => 'ICI', 'ap' => 'JIMENEZ', 'am' => 'MOLEON', 'nom' => 'MARIA DEL CARMEN'],
            ['lic' => 'ICI', 'ap' => 'LOPEZ', 'am' => 'ALBARRAN', 'nom' => 'MARIA FERNANDA'],
            ['lic' => 'ICI', 'ap' => 'LUCERO', 'am' => 'CHAVEZ', 'nom' => 'MERCEDES'],
            ['lic' => 'ICI', 'ap' => 'MANJARREZ', 'am' => 'GARDUÑO', 'nom' => 'LORENA ELIZABETH'],
            ['lic' => 'ICI', 'ap' => 'MILLAN', 'am' => 'LAGUNAS', 'nom' => 'ERICKA LIZETH'],
            ['lic' => 'ICI', 'ap' => 'NAJERA', 'am' => 'LOPEZ', 'nom' => 'MA DE LOURDES'],
            ['lic' => 'ICI', 'ap' => 'PEREZ', 'am' => 'FAJARDO', 'nom' => 'JOSE SATURNINO'],
            ['lic' => 'ICI', 'ap' => 'PEREZ', 'am' => 'MORALES', 'nom' => 'JUDITH'],
            ['lic' => 'ICI', 'ap' => 'RAMIREZ', 'am' => 'DE ALBA', 'nom' => 'HORACIO'],
            ['lic' => 'ICI', 'ap' => 'RAMIREZ', 'am' => 'REVUELTAS', 'nom' => 'LAURA'],
            ['lic' => 'ICI', 'ap' => 'ROMERO', 'am' => 'ARREOLA', 'nom' => 'CARLOS ARTURO'],
            ['lic' => 'ICI', 'ap' => 'ROMERO', 'am' => 'TORRES', 'nom' => 'JAVIER'],
            ['lic' => 'ICI', 'ap' => 'SUAREZ', 'am' => 'DE LA VEGA', 'nom' => 'MIRIAM ESTHELA'],
            ['lic' => 'ICI', 'ap' => 'TORRES', 'am' => 'SANCHEZ', 'nom' => 'MERCED'],
            ['lic' => 'ICI', 'ap' => 'VERTIZ', 'am' => 'CAMARON', 'nom' => 'GASTON'],
            ['lic' => 'ICO', 'ap' => 'ALBARRAN', 'am' => 'TRUJILLO', 'nom' => 'SILVIA EDITH'],
            ['lic' => 'ICO', 'ap' => 'ARZATE', 'am' => 'TREJO', 'nom' => 'ALVARO'],
            ['lic' => 'ICO', 'ap' => 'CONTRERAS', 'am' => 'FLORES', 'nom' => 'MARIA DE LOS ANGELES'],
            ['lic' => 'ICO', 'ap' => 'ESPINOSA DE LOS MONTEROS', 'am' => 'HEREDIA', 'nom' => 'LILIAN KARINA'],
            ['lic' => 'ICO', 'ap' => 'FABILA', 'am' => 'NUÑEZ', 'nom' => 'ARELI'],
            ['lic' => 'ICO', 'ap' => 'GUADALUPE', 'am' => 'RODRIGUEZ', 'nom' => 'CAMACHO'],
            ['lic' => 'ICO', 'ap' => 'MONTAÑO', 'am' => 'SERRANO', 'nom' => 'VICTOR MANUEL'],
            ['lic' => 'ICO', 'ap' => 'MUNGUIA', 'am' => 'CEDILLO', 'nom' => 'NATALIA CECILIA'],
            ['lic' => 'ICO', 'ap' => 'OROZCO', 'am' => 'GARDUÑO', 'nom' => 'BEATRIZ'],
            ['lic' => 'ICO', 'ap' => 'ROMERO', 'am' => 'HUERTAS', 'nom' => 'MARCELO'],
            ['lic' => 'ICO', 'ap' => 'ROMERO', 'am' => 'MARIANO', 'nom' => 'ESMERALDA'],
            ['lic' => 'ICO', 'ap' => 'SALGADO', 'am' => 'GALLEGOS', 'nom' => 'MIREYA'],
            ['lic' => 'ICO', 'ap' => 'VERA', 'am' => 'NOGUEZ', 'nom' => 'SARA'],
            ['lic' => 'ICO', 'ap' => 'SANCHEZ', 'am' => 'HERRERA', 'nom' => 'JUAN'],
            ['lic' => 'IEL', 'ap' => 'CABALLERO', 'am' => 'VIÑAS', 'nom' => 'JOSE'],
            ['lic' => 'IEL', 'ap' => 'COLIN', 'am' => 'MERCADO', 'nom' => 'NOE ARMANDO'],
            ['lic' => 'IEL', 'ap' => 'ESTRADA', 'am' => 'HERRERA', 'nom' => 'LUDIVINA DEL RAYO'],
            ['lic' => 'IEL', 'ap' => 'MORAN', 'am' => 'SOLANO', 'nom' => 'MARIA GUADALUPE'],
            ['lic' => 'IEL', 'ap' => 'MORENO', 'am' => 'JIMENEZ', 'nom' => 'JUDITH'],
            ['lic' => 'IEL', 'ap' => 'PEREZ', 'am' => 'CLAVEL', 'nom' => 'BENJAMIN'],
            ['lic' => 'IEL', 'ap' => 'PEREZ', 'am' => 'MERLOS', 'nom' => 'JUAN CARLOS'],
            ['lic' => 'IEL', 'ap' => 'RODRIGUEZ', 'am' => 'ANGELES', 'nom' => 'EDUARDO'],
        ];

        foreach ($profesores as $p) {
            // Ahora puedes buscar directamente en la DB porque no hay cifrado
            $licenciatura = Licenciatura::where('abreviatura', $p['lic'])->first();

            if ($licenciatura) {
                $nuevoProfesor = Profesor::create([
                    'apellido_paterno' => $p['ap'],
                    'apellido_materno' => $p['am'],
                    'nombre'           => $p['nom'],
                    'estado'           => 'Activo',
                ]);
                $nuevoProfesor->licenciaturas()->attach($licenciatura->id);
            }
        }
    }
}