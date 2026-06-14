<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Licenciatura extends Model
{
    protected $fillable = ['codigo', 'abreviatura', 'nombre'];

    // Se elimina el método casts() que contenía 'encrypted'
    
    public function profesores()
    {
        return $this->belongsToMany(Profesor::class, 'licenciatura_profesor');
    }
}