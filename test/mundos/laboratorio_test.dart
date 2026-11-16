import 'dart:ui' as ui;

import 'package:enfoque_app_mobile/mundos/galaxia/colocador_galaxia.dart';
import 'package:enfoque_app_mobile/mundos/galaxia/escena_galaxia.dart';
import 'package:enfoque_app_mobile/mundos/galaxia/pintor_codigo.dart';
import 'package:enfoque_app_mobile/mundos/galaxia/pintor_prueba.dart';
import 'package:enfoque_app_mobile/mundos/galaxia/vistas_galaxia.dart';
import 'package:enfoque_app_mobile/mundos/laboratorio/laboratorio_mundos_screen.dart';
import 'package:enfoque_app_mobile/screens/estadisticas_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../montaje.dart';

void main() {
  Future<void> avanzar(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  Widget laboratorio() => MaterialApp(
    home: LaboratorioMundosScreen(pintores: [PintorPrueba()], medir: false),
  );

  group('Laboratorio de mundos', () {
    testWidgets('empieza con 10 estrellas y la primera constelación cerrada', (
      tester,
    ) async {
      await tester.pumpWidget(laboratorio());
      await avanzar(tester);
      expect(
        find.text('10 estrellas · 1 constelaciones completas'),
        findsOneWidget,
      );
      expect(find.textContaining('· 10/10'), findsOneWidget);
    });

    testWidgets('1.000 piezas, todos los niveles de zoom y +1', (tester) async {
      await tester.pumpWidget(laboratorio());
      await avanzar(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, '1000'));
      await avanzar(tester);
      expect(
        find.text('1000 estrellas · 100 constelaciones completas'),
        findsOneWidget,
      );

      for (final nivel in ['Todo', 'Cerca', 'Hoy']) {
        await tester.tap(find.widgetWithText(ChoiceChip, nivel));
        await avanzar(tester);
      }

      await tester.tap(find.text('+1'));
      await avanzar(tester);
      expect(
        find.text('1001 estrellas · 100 constelaciones completas'),
        findsOneWidget,
      );
      expect(find.textContaining('· 1/10'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('se mueve y se acerca con los dedos sin romperse', (
      tester,
    ) async {
      await tester.pumpWidget(laboratorio());
      await avanzar(tester);
      final centro = tester.getCenter(find.byType(CustomPaint).first);
      await tester.dragFrom(centro, const Offset(120, -80));
      await avanzar(tester);
      final a = await tester.startGesture(centro - const Offset(40, 0));
      final b = await tester.startGesture(centro + const Offset(40, 0));
      await a.moveBy(const Offset(-60, 0));
      await b.moveBy(const Offset(60, 0));
      await a.up();
      await b.up();
      await avanzar(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('otra semilla y cambio de pintor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LaboratorioMundosScreen(
            pintores: [PintorPrueba(), PintorPrueba()],
            medir: false,
          ),
        ),
      );
      await avanzar(tester);
      expect(find.textContaining('semilla 2026'), findsOneWidget);
      await tester.tap(find.text('Otra semilla'));
      await avanzar(tester);
      expect(find.textContaining('semilla 2026'), findsNothing);
      await tester.tap(find.text('Pintor: Prueba'));
      await avanzar(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('Pintor de código', () {
    testWidgets('carga el shader y pinta 1.000 estrellas en los tres niveles', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final pintor = PintorCodigo();
        await pintor.preparar();
        expect(pintor.conShader, isTrue);
        const tamano = ui.Size(200, 400);
        final escena = EscenaGalaxia(ColocadorGalaxia(2026), 1000);
        for (final nivel in NivelZoom.values) {
          final grabadora = ui.PictureRecorder();
          pintor.pintar(
            ui.Canvas(grabadora),
            tamano,
            VistasGalaxia.de(nivel, escena, tamano),
            escena,
            segundos: 1,
            nueva: 999,
            aparicion: 0.5,
          );
          final imagen = await grabadora.endRecording().toImage(200, 400);
          final datos = await imagen.toByteData();
          // Algo se ha pintado: no es todo del color del fondo.
          final bytes = datos!.buffer.asUint8List();
          var claros = 0;
          for (var i = 0; i < bytes.length; i += 4) {
            if (bytes[i] + bytes[i + 1] + bytes[i + 2] > 300) claros++;
          }
          expect(claros, greaterThan(20), reason: nivel.name);
        }
        pintor.liberar();
      });
    });

    testWidgets('sin shader, pinta igual con un degradado', (tester) async {
      await tester.runAsync(() async {
        final pintor = PintorCodigo(rutaShader: 'shaders/no_existe.frag');
        await pintor.preparar();
        expect(pintor.conShader, isFalse);
        const tamano = ui.Size(200, 400);
        final escena = EscenaGalaxia(ColocadorGalaxia(2026), 10);
        final grabadora = ui.PictureRecorder();
        pintor.pintar(
          ui.Canvas(grabadora),
          tamano,
          VistasGalaxia.hoy(escena, tamano),
          escena,
          segundos: 0,
        );
        grabadora.endRecording();
        pintor.liberar();
      });
    });
  });

  group('Entrada desde Estadísticas', () {
    testWidgets('en la app de prueba, el botón está y abre el laboratorio', (
      tester,
    ) async {
      final m = Montaje(tester);
      await tester.pumpWidget(
        m.app(const Scaffold(body: EstadisticasScreen())),
      );
      await avanzar(tester);
      final boton = find.byKey(const Key('abrir-laboratorio-mundos'));
      await tester.scrollUntilVisible(boton, 200);
      expect(boton, findsOneWidget);
    });

    testWidgets('en la de Play, no hay botón', (tester) async {
      final m = Montaje(tester, flavor: 'produccion');
      await tester.pumpWidget(
        m.app(const Scaffold(body: EstadisticasScreen())),
      );
      await avanzar(tester);
      expect(find.byKey(const Key('abrir-laboratorio-mundos')), findsNothing);
    });
  });
}
