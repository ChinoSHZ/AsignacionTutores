<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        // ── Paso 1: agregar nullable temporalmente ──
        Schema::table('semestres', function (Blueprint $table) {
            // Usamos string temporalmente para evitar conflictos de tipos en el cambio
            $table->string('tipo')->nullable()->after('clave');
        });

        // ── Paso 2: asignar tipos y limpiar ──
        $total = DB::table('semestres')->count();

        if ($total > 0) {
            $actual = DB::table('semestres')
                ->orderBy('clave', 'desc')
                ->first();

            DB::table('semestres')
                ->where('id', $actual->id)
                ->update(['tipo' => 'actual']);

            $anterior = DB::table('semestres')
                ->whereNull('tipo')
                ->orderBy('clave', 'desc')
                ->first();

            if ($anterior) {
                DB::table('semestres')
                    ->where('id', $anterior->id)
                    ->update(['tipo' => 'anterior']);
            }

            DB::table('semestres')->whereNull('tipo')->delete();
        }

        // ── Paso 3: Aplicar restricciones finales (Postgres Safe) ──
        // 1. Forzamos el NOT NULL y el UNIQUE
        Schema::table('semestres', function (Blueprint $table) {
            $table->string('tipo')->nullable(false)->unique()->change();
        });

        // 2. Agregamos el Check Constraint manualmente para que funcione como un ENUM
        DB::statement('ALTER TABLE semestres ADD CONSTRAINT check_tipo_semestres CHECK (tipo IN (\'actual\', \'anterior\'))');
    }

    public function down(): void
    {
        Schema::table('semestres', function (Blueprint $table) {
            // Eliminamos el constraint manual primero
            DB::statement('ALTER TABLE semestres DROP CONSTRAINT IF EXISTS check_tipo_semestres');
            $table->dropUnique(['tipo']);
            $table->dropColumn('tipo');
        });
    }
};