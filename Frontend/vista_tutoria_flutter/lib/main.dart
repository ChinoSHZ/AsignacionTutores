import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(const MaterialApp(home: VisualizadorTablas()));

class VisualizadorTablas extends StatefulWidget {
  const VisualizadorTablas({super.key});

  @override
  State<VisualizadorTablas> createState() => _VisualizadorTablasState();
}

class _VisualizadorTablasState extends State<VisualizadorTablas> {
  List tablas = [];      // Almacena los nombres de las tablas
  List datos = [];       // Almacena los registros de la tabla seleccionada
  String? tablaSeleccionada;

  // IMPORTANTE: 
  // Usa 'http://127.0.0.1:8000/api' para Chrome.
  // Usa 'http://10.0.2.2:8000/api' si usas el emulador de Android.
  final String urlApi = "http://127.0.0.1:8000/api";

  @override
  void initState() {
    super.initState();
    fetchTablas(); // Carga las tablas al iniciar la app
  }

  // Petición al endpoint /tablas de Laravel
  Future<void> fetchTablas() async {
    try {
      final response = await http.get(Uri.parse('$urlApi/tablas'));
      if (response.statusCode == 200) {
        setState(() {
          tablas = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Error de conexión: $e");
    }
  }

  // Petición al endpoint /datos/{tabla}
  Future<void> fetchDatos(String nombreTabla) async {
    try {
      final response = await http.get(Uri.parse('$urlApi/datos/$nombreTabla'));
      if (response.statusCode == 200) {
        setState(() {
          datos = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Error al traer datos: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Monitor PostgreSQL - Shiha")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Dropdown (Combo Box) para elegir la tabla
            DropdownButton<String>(
              isExpanded: true,
              hint: const Text("Selecciona una tabla"),
              value: tablaSeleccionada,
              items: tablas.map((t) {
                return DropdownMenuItem<String>(
                  value: t['table_name'],
                  child: Text(t['table_name'].toString().toUpperCase()),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  tablaSeleccionada = val;
                  datos = []; // Limpia la tabla previa
                });
                fetchDatos(val!);
              },
            ),
            const SizedBox(height: 20),
            // Tabla dinámica
            Expanded(
              child: datos.isEmpty
                  ? const Center(child: Text("Sin registros o cargando..."))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          // Genera columnas basadas en las llaves del JSON
                          columns: (datos[0] as Map).keys.map((key) {
                            return DataColumn(label: Text(key, style: const TextStyle(fontWeight: FontWeight.bold)));
                          }).toList(),
                          // Genera filas basadas en los valores
                          rows: datos.map((row) {
                            return DataRow(
                              cells: (row as Map).values.map((v) => DataCell(Text(v.toString()))).toList(),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}