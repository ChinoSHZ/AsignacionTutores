<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Grupo extends Model
{
    protected $table = 'grupos';

    protected $fillable = [
        'semestre_id',
        'tutor_id',
        'licenciatura_id',
        'estado_tutor',
    ];

    public function semestre()
    {
        return $this->belongsTo(Semestre::class);
    }

    public function tutor()
    {
        return $this->belongsTo(Profesor::class, 'tutor_id');
    }

    public function licenciatura()
    {
        return $this->belongsTo(Licenciatura::class);
    }

    /**
     * Tutorados del grupo con todos los campos del pivot grupo_tutorado.
     */
    public function tutorados()
    {
        return $this->belongsToMany(Tutorado::class, 'grupo_tutorado')
                    ->withPivot('semestre_id', 'estado_tutorado', 'movilidad')
                    ->withTimestamps();
    }
}