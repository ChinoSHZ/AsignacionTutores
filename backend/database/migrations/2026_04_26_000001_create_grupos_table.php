<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * MIGRACIÓN 2 de 3
 *
 * Crea la tabla 'grupos'.
 *
 * Un grupo es la unidad de asignación en un semestre específico:
 * relaciona a UN tutor con UN conjunto de tutorados dentro de UN semestre.
 *
 * Relaciones:
 *   - semestres  (1) → grupos (N) : un semestre tiene múltiples grupos
 *   - profesores (1) → grupos (N) : un tutor puede coordinar varios grupos
 *
 * ON DELETE CASCADE en semestre_id:
 *   Cuando se elimina un semestre (ej. el 'anterior' al avanzar),
 *   todos sus grupos se eliminan automáticamente sin lógica adicional.
 *
 * NOTA sobre tutor_id:
 *   La tabla 'profesores' usa UUID como PK, por eso se define
 *   la FK manualmente en lugar de usar foreignId().
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('grupos', function (Blueprint $table) {
            $table->id();

            // FK → semestres. CASCADE: al borrar semestre se borran sus grupos
            $table->foreignId('semestre_id')
                  ->constrained('semestres')
                  ->onDelete('cascade');

            // FK → profesores (UUID). CASCADE: al borrar tutor se borran sus grupos
            $table->uuid('tutor_id');
            $table->foreign('tutor_id')
                  ->references('id')
                  ->on('profesores')
                  ->onDelete('cascade');

            // Estado del tutor registrado en el momento de este semestre.
            // Permite saber si el tutor estaba activo o de baja en ese periodo.
            $table->enum('estado_tutor', ['activo', 'baja'])->default('activo');

            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('grupos');
    }
};
