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

        // 2. Creamos la tabla pivot intermedia
        Schema::create('licenciatura_profesor', function (Blueprint $table) {
            $table->id();
            // Importante: profesor_id debe ser uuid para coincidir con la tabla profesores
            $table->uuid('profesor_id');
            // licenciatura_id es numérico para coincidir con la tabla licenciaturas
            $table->foreignId('licenciatura_id')->constrained('licenciaturas')->onDelete('cascade');
            $table->timestamps();

            // Definición manual de la llave foránea para el UUID
            $table->foreign('profesor_id')->references('id')->on('profesores')->onDelete('cascade');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('licenciatura_profesor');
        
    }
};