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
        Schema::create('licenciaturas', function (Blueprint $table) {
            $table->id(); // ID numérico interno
            $table->string('codigo')->unique(); // Para guardar C01, C02, etc.
            $table->text('abreviatura'); // Campo cifrado
            $table->text('nombre');      // Campo cifrado
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('licenciaturas');
    }
};
