<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Tutorado extends Model
{
    protected $table = 'tutorados';

    protected $fillable = [
        'numero_cuenta',
        'nombre',
        'apellido_paterno',
        'apellido_materno',
        'periodo_ingreso',
        'licenciatura_id',
        'is_active',
    ];

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
        ];
    }

    // ── Relaciones ─────────────────────────────────────────

    /**
     * Un tutorado pertenece a una licenciatura.
     */
    public function licenciatura()
    {
        return $this->belongsTo(Licenciatura::class);
    }

    /**
     * Un tutorado puede estar en múltiples grupos a lo largo de su carrera 
     * (uno por semestre).
     */
    public function grupos()
    {
        return $this->belongsToMany(Grupo::class, 'grupo_tutorado')
                    ->withPivot('semestre_id', 'estado_tutorado', 'movilidad')
                    ->withTimestamps();
    }

    // ── Accesores (Opcional) ───────────────────────────────
    // Este helper te sirve para enviarle el nombre completo a Flutter tal cual lo espera
    public function getNombreCompletoAttribute()
    {
        return trim("{$this->nombre} {$this->apellido_paterno} {$this->apellido_materno}");
    }
}