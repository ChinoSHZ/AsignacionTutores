<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('licenciatura_profesor', function (Blueprint $table) {
            $table->id();
            
            $table->foreignId('licenciatura_id')
                  ->constrained('licenciaturas')
                  ->onDelete('cascade');
                  
            $table->uuid('profesor_id');
            $table->foreign('profesor_id')
                  ->references('id')
                  ->on('profesores')
                  ->onDelete('cascade');
                  
            $table->timestamps();
            
            $table->unique(['licenciatura_id', 'profesor_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('licenciatura_profesor');
    }
};