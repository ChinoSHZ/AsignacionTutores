<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids; // Para manejar UUIDs automáticamente
use Illuminate\Database\Eloquent\Model;

class Profesor extends Model
{
    use HasUuids;

    protected $table = 'profesores';

    protected $fillable = [
        'apellido_paterno',
        'apellido_materno',
        'nombre',
        'correo',
        'licenciatura_id',
        'estado'
    ];

    protected function casts(): array
    {
        return [
            'apellido_paterno' => 'encrypted',
            'apellido_materno' => 'encrypted',
            'nombre' => 'encrypted',
            'correo' => 'encrypted',
        ];
    }

    public function licenciaturas()
    {
        return $this->belongsToMany(Licenciatura::class, 'licenciatura_profesor');
    }
}
