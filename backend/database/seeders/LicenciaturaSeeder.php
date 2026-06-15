<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class LicenciaturaSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $carreras = [
            ['codigo' => 'C00', 'abreviatura' => 'S/L', 'nombre' => 'Sin licenciatura'], // <-- LÍNEA NUEVA
            ['codigo' => 'C01', 'abreviatura' => 'ICO', 'nombre' => 'Licenciatura de Ingeniería en Computación'],
            ['codigo' => 'C02', 'abreviatura' => 'IME', 'nombre' => 'Licenciatura de Ingeniería Mecánica'],
            ['codigo' => 'C03', 'abreviatura' => 'ISES', 'nombre' => 'Licenciatura de Ingeniería en Sistemas Energéticos Sustentables'],
            ['codigo' => 'C04', 'abreviatura' => 'ICI', 'nombre' => 'Licenciatura de Ingeniería Civil'],
            ['codigo' => 'C05', 'abreviatura' => 'IEL', 'nombre' => 'Licenciatura de Ingeniería en Electrónica'],
            ['codigo' => 'C06', 'abreviatura' => 'IIA', 'nombre' => 'Licenciatura de Ingeniería en Inteligencia Artificial'],
        ];

        foreach ($carreras as $carrera) {
            \App\Models\Licenciatura::create($carrera);
        }
    }
}