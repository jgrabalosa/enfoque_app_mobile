import 'package:enfoque_app_mobile/services/abrir_habits.dart';
import 'package:enfoque_app_mobile/services/canal_sistema.dart';
import 'package:flutter_test/flutter_test.dart';

class _Lanzador implements Lanzador {
  _Lanzador(this.abre);
  final bool Function({Uri? enlace, String? paquete}) abre;
  final List<({Uri? enlace, String? paquete})> llamadas = [];

  @override
  Future<bool> abrir({Uri? enlace, String? paquete}) async {
    llamadas.add((enlace: enlace, paquete: paquete));
    return abre(enlace: enlace, paquete: paquete);
  }
}

/// «Crea hábitos en Norday Habits»: Habits si está, si no su ficha de Play,
/// si no la web.
void main() {
  test('con Habits instalada, se abre Habits y nada más', () async {
    final l = _Lanzador(({enlace, paquete}) => enlace == null);
    expect(
      await abrirHabits(flavor: 'produccion', lanzador: l),
      AperturaHabits.app,
    );
    expect(l.llamadas, [(enlace: null, paquete: 'com.norday.habitos')]);
  });

  test('la Focus de prueba abre la Habits de prueba', () async {
    final l = _Lanzador(({enlace, paquete}) => true);
    await abrirHabits(flavor: 'prueba', lanzador: l);
    expect(l.llamadas.single.paquete, 'com.norday.habitos.prueba');
  });

  test('sin Habits, la ficha de Play; sin Play, la web', () async {
    final soloPlay = _Lanzador(
      ({enlace, paquete}) => enlace?.scheme == 'market',
    );
    expect(
      await abrirHabits(flavor: null, lanzador: soloPlay),
      AperturaHabits.fichaPlay,
    );
    expect(
      soloPlay.llamadas.last.enlace.toString(),
      'market://details?id=com.norday.habitos',
    );

    final soloWeb = _Lanzador(({enlace, paquete}) => enlace?.scheme == 'https');
    expect(
      await abrirHabits(flavor: null, lanzador: soloWeb),
      AperturaHabits.fichaWeb,
    );
    expect(
      soloWeb.llamadas.last.enlace.toString(),
      'https://play.google.com/store/apps/details?id=com.norday.habitos',
    );
  });

  test('la Focus de prueba sin la Habits de prueba no cae a Play', () async {
    // Aunque Play y la web abrirían: su ficha es la de producción.
    final l = _Lanzador(({enlace, paquete}) => enlace != null);
    expect(
      await abrirHabits(flavor: 'prueba', lanzador: l),
      AperturaHabits.faltaPrueba,
    );
    expect(l.llamadas, [(enlace: null, paquete: 'com.norday.habitos.prueba')]);
  });

  test('nada que abra nada', () async {
    final l = _Lanzador(({enlace, paquete}) => false);
    expect(await abrirHabits(flavor: null, lanzador: l), AperturaHabits.nada);
    expect(l.llamadas, hasLength(3));
  });
}
