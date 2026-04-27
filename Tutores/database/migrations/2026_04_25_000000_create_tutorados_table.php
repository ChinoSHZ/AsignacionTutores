<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('tutorados', function (Blueprint $table) {
            // Genera la PK BIGINT UNSIGNED (coincide con foreignId)
            $table->id(); 
            
            // Número de cuenta de la UAEMéx (único)
            $table->string('numero_cuenta')->unique(); 
            
            // Datos personales (Separados para mejor normalización)
            $table->string('nombre');
            $table->string('apellido_paterno');
            $table->string('apellido_materno')->nullable();
            
            // Periodo en el que ingresó (Ej. '2023B', '2024A')
            $table->string('periodo_ingreso'); 

            // Relación con su carrera
            $table->foreignId('licenciatura_id')->constrained('licenciaturas');

            // Estado del alumno (Activo o de Baja) - Coincide con 'isActive' de Flutter
            $table->boolean('is_active')->default(true);

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('tutorados');
    }
};