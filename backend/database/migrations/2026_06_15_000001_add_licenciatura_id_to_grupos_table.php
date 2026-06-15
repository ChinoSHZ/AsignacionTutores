<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Agrega licenciatura_id a la tabla grupos.
 *
 * Cada grupo ahora pertenece a UNA licenciatura específica.
 * Esto permite que un tutor con múltiples licenciaturas tenga
 * un grupo separado por cada una, evitando mezclar alumnos
 * de distintas carreras en un solo grupo (el bug "S/L").
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('grupos', function (Blueprint $table) {
            $table->foreignId('licenciatura_id')
                  ->nullable()
                  ->after('tutor_id')
                  ->constrained('licenciaturas')
                  ->onDelete('cascade');
        });
    }

    public function down(): void
    {
        Schema::table('grupos', function (Blueprint $table) {
            $table->dropForeign(['licenciatura_id']);
            $table->dropColumn('licenciatura_id');
        });
    }
};