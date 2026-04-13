<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // Puedes mantener tu usuario de prueba si lo requieres
        User::factory()->create([
            'name' => 'Test User',
            'email' => 'test@example.com',
        ]);

        // Llamamos a los seeders explícitamente y en orden jerárquico
        $this->call([
            LicenciaturaSeeder::class, // Primero las licenciaturas
            ProfesorSeeder::class,     // Luego los profesores que dependen de ellas
        ]);
    }
}