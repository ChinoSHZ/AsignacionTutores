<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('semestres', function (Blueprint $table) {
            $table->id();
            // Clave única del semestre, ej: '2024A', '2024B', '2025A'
            $table->string('clave')->unique();
            // Declaración explícita del enum soportada por la abstracción de Laravel en SQLite
            $table->enum('tipo', ['actual', 'anterior']);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('semestres');
    }
};
