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
        Schema::create('profesores', function (Blueprint $table) {
            $table->uuid('id')->primary(); // Llave primaria UUID
            $table->text('apellido_paterno'); // Campo cifrado
            $table->text('apellido_materno')->nullable(); // Campo cifrado opcional
            $table->text('nombre'); // Campo cifrado
            $table->text('correo')->nullable(); // Campo cifrado opcional
            $table->foreignId('licenciatura_id')->constrained('licenciaturas'); // Relación con Licenciaturas
            $table->string('estado')->default('Activo'); // 'Activo' o 'Baja'
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('profesores');
    }
};
