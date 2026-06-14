import 'package:flutter_test/flutter_test.dart';
import 'package:vista_tutoria_flutter/main.dart'; // Asegúrate de que el nombre del package coincida con el tuyo

void main() {
  testWidgets('App basic smoke test', (WidgetTester tester) async {
    // Construye nuestra app (usando la clase correcta) y dispara un frame.
    await tester.pumpWidget(const TutorAssignmentApp());

    // Como ya no tenemos un contador, vamos a verificar que la app 
    // renderice correctamente buscando el título de nuestra barra lateral.
    expect(find.text('TutorAssign'), findsWidgets);
  });
}