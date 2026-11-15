import 'package:enfoque_app_mobile/services/al_volver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Al volver a primer plano: identidad, aviso del móvil y sesiones
/// pendientes, sin que un fallo llegue a quien llama.
void main() {
  test('con usuario: registra el aviso y reenvía lo pendiente', () async {
    final hecho = <String>[];
    alVolverAPrimerPlano(
      7,
      enviarPendientes: () async => hecho.add('enviar'),
      recargarIdentidad: (_) async => true,
      registrarAviso: (id) async => hecho.add('aviso $id'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(hecho, containsAll(['enviar', 'aviso 7']));
  });

  test('sin usuario: nada', () async {
    final hecho = <String>[];
    alVolverAPrimerPlano(
      0,
      enviarPendientes: () async => hecho.add('enviar'),
      recargarIdentidad: (_) async => true,
      registrarAviso: (id) async => hecho.add('aviso'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(hecho, isEmpty);
  });

  test('un fallo no sale', () async {
    alVolverAPrimerPlano(
      7,
      enviarPendientes: () async => throw StateError('sin red'),
      recargarIdentidad: (_) async => throw StateError('sin red'),
      registrarAviso: (_) async => throw StateError('sin red'),
    );
    await Future<void>.delayed(Duration.zero);
  });
}
