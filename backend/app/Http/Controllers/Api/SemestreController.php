<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Semestre;

class SemestreController extends Controller
{
    public function index()
    {
        // Devuelve todos los semestres (el actual y el anterior)
        return response()->json(Semestre::all());
    }
}