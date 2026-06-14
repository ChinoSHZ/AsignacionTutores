<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;

class Semestre extends Model
{
    protected $table = 'semestres';
    protected $fillable = ['clave', 'tipo'];

    public static function actual()
    {
        return self::where('tipo', 'actual')->first();
    }

    public static function anterior(): ?self
    {
        return self::where('tipo', 'anterior')->first();
    }

    /**
     * Lógica de Ventana Deslizante: Avanzar al siguiente semestre
     */
    public static function avanzar($nuevaClave)
    {
        return DB::transaction(function () use ($nuevaClave) {
            // 1. Identificar y eliminar el semestre que ya es 'anterior'
            // Esto dispara el DELETE CASCADE en cascada en la DB
            self::where('tipo', 'anterior')->delete();

            // 2. El semestre que es 'actual' ahora pasa a ser 'anterior'
            self::where('tipo', 'actual')->update(['tipo' => 'anterior']);

            // 3. Crear el nuevo semestre como 'actual'
            return self::create([
                'clave' => $nuevaClave,
                'tipo'  => 'actual'
            ]);
        });
    }
}