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
            // Agregamos cifrado a los campos de texto
            'nombre' => 'encrypted',
            'apellido_paterno' => 'encrypted',
            'apellido_materno' => 'encrypted',
        ];
    }

    public function licenciatura()
    {
        return $this->belongsTo(Licenciatura::class);
    }

    public function grupos()
    {
        return $this->belongsToMany(Grupo::class, 'grupo_tutorado')
                    ->withPivot('semestre_id', 'estado_tutorado', 'movilidad')
                    ->withTimestamps();
    }
}