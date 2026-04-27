<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * MIGRACIÓN 3 de 3
 *
 * Crea la tabla 'grupo_tutorado'.
 *
 * Es la tabla pivote central del sistema: registra qué tutorado
 * pertenece a qué grupo en qué semestre, y cuál era su estado
 * y movilidad en ese momento específico.
 *
 * Relaciones:
 *   - grupos    (1) → grupo_tutorado (N) : un grupo tiene muchos tutorados
 *   - tutorados (1) → grupo_tutorado (N) : un tutorado aparece en distintos semestres
 *   - semestres (1) → grupo_tutorado (N) : semestre_id está aquí de forma redundante
 *                                          intencional para poder aplicar el UNIQUE
 *                                          directamente sin hacer JOIN a través de grupos
 *
 * Restricción clave:
 *   UNIQUE(tutorado_id, semestre_id) garantiza que un tutorado
 *   solo puede pertenecer a UN grupo por semestre, sin importar
 *   cuántos grupos existan en ese semestre.
 *
 * ON DELETE CASCADE en grupo_id y semestre_id:
 *   Al eliminar un grupo o semestre, sus asignaciones desaparecen
 *   automáticamente. Esto es lo que permite que /avanzar limpie
 *   el semestre 'anterior' con un solo DELETE.
 *
 * NOTA sobre tutorado_id:
 *   La tabla 'tutorados' aún no existe en tus migraciones actuales.
 *   Cuando la crees, asegúrate de que su PK sea INT (no UUID) para
 *   que coincida con el foreignId() usado aquí.
 *   Si decides usar UUID para tutorados, cambia foreignId() por
 *   uuid() + foreign() manual, igual que se hizo con tutor_id en grupos.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('grupo_tutorado', function (Blueprint $table) {
            // No se usa $table->id() porque la PK compuesta ya identifica la fila.
            // Se agrega un id simple para facilitar operaciones de Eloquent.
            $table->id();

            // FK → grupos. CASCADE: al borrar grupo se borran sus asignaciones
            $table->foreignId('grupo_id')
                  ->constrained('grupos')
                  ->onDelete('cascade');

            // FK → tutorados.
            // AJUSTA el tipo si tu tabla tutorados usa UUID en lugar de INT.
            $table->foreignId('tutorado_id')
                  ->constrained('tutorados')
                  ->onDelete('cascade');

            // FK → semestres. CASCADE: al borrar semestre se borran sus asignaciones.
            // Redundante con grupo_id pero necesario para el UNIQUE de abajo.
            $table->foreignId('semestre_id')
                  ->constrained('semestres')
                  ->onDelete('cascade');

            // Estado del tutorado registrado en este semestre específico.
            $table->enum('estado_tutorado', ['activo', 'baja'])->default('activo');

            // Movilidad del tutorado en este semestre.
            // Al avanzar semestre, los reingresantes se copian como 'no_cambiar'
            // y el coordinador ajusta manualmente los que sean necesarios.
            $table->enum('movilidad', ['cambiar', 'no_cambiar', 'nuevo_ingreso'])
                  ->default('no_cambiar');

            $table->timestamps();

            // ── Restricción clave del sistema ─────────────────────────────────
            // Un tutorado solo puede estar en UN grupo por semestre.
            // Intentar insertar el mismo tutorado dos veces en el mismo semestre
            // lanzará un error de base de datos antes de llegar a la lógica PHP.
            $table->unique(['tutorado_id', 'semestre_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('grupo_tutorado');
    }
};
