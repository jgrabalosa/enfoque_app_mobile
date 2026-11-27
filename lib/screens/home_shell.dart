import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:norday_flutter_core/norday_flutter_core.dart';

import '../l10n/app_localizations.dart';
import '../services/al_volver.dart';
import '../services/controlador_enfoque.dart';
import '../services/servicios_enfoque.dart';
import '../widgets/barra_navegacion.dart';
import 'como_funciona_screen.dart';
import 'descanso_screen.dart';
import 'estadisticas_screen.dart';
import 'inicio_screen.dart';
import 'resultado_screen.dart';
import 'sesion_screen.dart';

/// Adónde va el motor cuando la sesión ya es buena.
///
/// `LoginScreen` y `PerfilScreen` viven en norday_flutter_core y no pueden
/// conocer `HomeShell` —el paquete no importa de la app—, así que se lo
/// decimos con esto. Norday Focus no tiene recorrido de bienvenida propio:
/// `mostrarOnboarding` no cambia nada (la elección de identidad ya la hace el
/// login del core).
Widget destinoTrasLogin(BuildContext context, bool mostrarOnboarding) =>
    const HomeShell();

/// Igual que [destinoTrasLogin] pero intercalando la elección de identidad
/// cuando el usuario no tiene ninguna.
///
/// [poseeIdentidad] viene de `Equipamiento.cargarDeUsuarioSiSePuede`: `null`
/// significa que no se pudo averiguar, y entonces se deja pasar. Un corte de
/// red al arrancar no puede encerrar a nadie en una pantalla sin salida.
Widget destinoConIdentidad(
  BuildContext context,
  bool mostrarOnboarding,
  bool? poseeIdentidad,
  int usuarioId,
) {
  if (poseeIdentidad == false) {
    return EleccionIdentidadScreen(
      usuarioId: usuarioId,
      alElegir: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeShell()),
      ),
    );
  }
  return const HomeShell();
}

/// Inicio y Estadísticas, más un menú con las pantallas del core (Nori,
/// tienda, logros, colección y perfil).
///
/// También decide qué se ve encima: con una sesión activa, la pantalla de
/// sesión; con una sesión recién acabada, su resultado. Lo decide aquí y no
/// cada pantalla para que valga igual al empezar, al recomponer una sesión
/// tras matar la app y al volver de otra app.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tabIndex = 0;
  int _usuarioId = 0;
  bool _loading = true;
  final _pageController = PageController();
  DateTime? _ultimaPulsacionAtras;

  ServiciosEnfoque? _servicios;
  ControladorEnfoque get _controlador => _servicios!.controlador;

  /// Si la pantalla de sesión está encima.
  bool _sesionAbierta = false;

  /// Si la pantalla de descanso entre rondas está encima.
  bool _descansoAbierto = false;

  /// La clave del último resultado ya enseñado: no se enseña dos veces.
  String? _resultadoMostrado;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_servicios != null) return;
    _servicios = AmbitoEnfoque.de(context);
    _controlador.motor.sesion.addListener(_sincronizarRuta);
    _controlador.resultado.addListener(_sincronizarRuta);
    _cargarUsuario();
    unawaited(_iniciarControlador());
  }

  Future<void> _iniciarControlador() async {
    await _controlador.iniciar();
    await _servicios!.tanda.limpiarSiHuerfana();
    if (mounted) _sincronizarRuta();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      alVolverAPrimerPlano(
        _usuarioId,
        enviarPendientes: _controlador.enviarPendientes,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controlador.motor.sesion.removeListener(_sincronizarRuta);
    _controlador.resultado.removeListener(_sincronizarRuta);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _cargarUsuario() async {
    final id = await _servicios!.usuarioActual();
    if (!mounted) return;
    setState(() {
      _usuarioId = id ?? 0;
      _loading = false;
    });
  }

  /// Pone encima la sesión o el resultado que toque. Se llama cada vez que
  /// cambia la sesión del motor o el resultado del controlador.
  void _sincronizarRuta() {
    if (!mounted) return;
    final sesion = _controlador.motor.sesion.value;
    final resultado = _controlador.resultado.value;
    final navegador = Navigator.of(context);
    if (sesion != null && sesion.estado.activa) {
      if (_sesionAbierta) return;
      _sesionAbierta = true;
      navegador
          .push(
            MaterialPageRoute(
              builder: (_) => SesionScreen(controlador: _controlador),
            ),
          )
          .whenComplete(() => _sesionAbierta = false);
      return;
    }
    final tanda = _servicios!.tanda;
    if (resultado != null && resultado.clave != _resultadoMostrado) {
      _resultadoMostrado = resultado.clave;
      // Lo que hubiera encima (la sesión) se va: el resultado la sustituye.
      // Hasta la ruta de este HomeShell, que no tiene por qué ser la primera.
      final propia = ModalRoute.of(context);
      navegador.popUntil((r) => r == propia || r.isFirst);
      // Una ronda completada que no es la última da paso al descanso; lo
      // demás, al resultado de siempre.
      if (tanda.alAcabar(resultado)) {
        _abrirDescanso(navegador);
      } else {
        navegador.push(
          MaterialPageRoute(
            builder: (_) => ResultadoScreen(controlador: _controlador),
          ),
        );
      }
      return;
    }
    // Se mató la app en el descanso: al volver, el descanso sigue.
    if (resultado == null && (tanda.tanda.value?.enDescanso ?? false)) {
      _abrirDescanso(navegador);
    }
  }

  void _abrirDescanso(NavigatorState navegador) {
    if (_descansoAbierto) return;
    _descansoAbierto = true;
    navegador
        .push(
          MaterialPageRoute(
            builder: (_) => DescansoScreen(
              controlador: _controlador,
              tanda: _servicios!.tanda,
            ),
          ),
        )
        .whenComplete(() => _descansoAbierto = false);
  }

  void _irAPestana(int i) {
    _pageController.animateToPage(
      i,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _abrir(Widget pantalla) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
  }

  // Botón atrás Android: si no estás en Inicio, vuelve ahí primero. Si ya
  // estás en Inicio, hace falta pulsar dos veces seguidas para salir.
  Future<void> _manejarAtras() async {
    if (_tabIndex != 0) {
      _irAPestana(0);
      return;
    }
    final ahora = DateTime.now();
    final esSegunda =
        _ultimaPulsacionAtras != null &&
        ahora.difference(_ultimaPulsacionAtras!) < const Duration(seconds: 2);
    if (esSegunda) {
      SystemNavigator.pop();
      return;
    }
    _ultimaPulsacionAtras = ahora;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.shellPulsaAtras),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _logout() async {
    await ApiServiceCore.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(destinoTrasLogin: destinoTrasLogin),
      ),
    );
  }

  /// El menú, anclado abajo a la derecha, encima del botón que lo abre, como
  /// en Norday Habits.
  void _abrirMenu() {
    final l = AppLocalizations.of(context)!;
    final c = NordayCoreLocalizations.of(context)!;
    final t = tokens(context);
    final id = identidad(context);
    final estiloEntrada = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: t.text);

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (hoja) {
        Widget entrada(IconData icono, String texto, VoidCallback alPulsar) {
          return InkWell(
            onTap: () {
              // Se cierra ANTES de navegar: si no, la ruta nueva se empuja
              // debajo del panel y queda tapada.
              Navigator.pop(hoja);
              alPulsar();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.ms,
              ),
              child: Row(
                children: [
                  Icon(icono, size: 18, color: t.points),
                  const SizedBox(width: AppSpacing.ms),
                  Text(texto, style: estiloEntrada),
                ],
              ),
            ),
          );
        }

        return Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.only(
              right: AppSpacing.sm,
              left: AppSpacing.sm,
              bottom: MediaQuery.of(context).padding.bottom + 88,
            ),
            child: Material(
              color: t.surface,
              elevation: 8,
              borderRadius: BorderRadius.circular(id.radioSecundario),
              clipBehavior: Clip.antiAlias,
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    entrada(
                      LucideIcons.pawPrint,
                      l.menuNori,
                      () => _abrir(
                        MascotaScreen(
                          usuarioId: _usuarioId,
                          // Los textos los pone la app: el ánimo y la XP de
                          // Nori salen de Focus y de Norday Habits juntos
                          // (backend V27, 16-nov-2026).
                          ayudaAnimo: AyudaCampo(
                            texto: l.mascotaAyudaAnimo,
                            etiquetaSemantica: l.mascotaAyudaAnimoEtiqueta,
                            superindice: true,
                          ),
                          ayudaXp: AyudaCampo(
                            texto: l.mascotaAyudaXp,
                            etiquetaSemantica: l.mascotaAyudaXpEtiqueta,
                            superindice: true,
                          ),
                        ),
                      ),
                    ),
                    entrada(
                      LucideIcons.store,
                      c.tiendaTitulo,
                      () => _abrir(TiendaScreen(usuarioId: _usuarioId)),
                    ),
                    entrada(
                      LucideIcons.medal,
                      c.logrosTitulo,
                      () => _abrir(LogrosScreen(usuarioId: _usuarioId)),
                    ),
                    entrada(
                      LucideIcons.trophy,
                      c.navColeccion,
                      () => _abrir(ColeccionScreen(usuarioId: _usuarioId)),
                    ),
                    entrada(
                      LucideIcons.userRound,
                      c.perfilTitulo,
                      () => _abrir(
                        PerfilScreen(
                          usuarioId: _usuarioId,
                          destinoTrasLogin: destinoTrasLogin,
                        ),
                      ),
                    ),
                    entrada(
                      LucideIcons.circleQuestionMark,
                      l.menuComoFunciona,
                      () => _abrir(const ComoFuncionaScreen()),
                    ),
                    entrada(
                      LucideIcons.mail,
                      l.menuEscribirANorday,
                      () => escribirANordayDesdeApp(context),
                    ),
                    entrada(LucideIcons.logOut, l.shellCerrarSesion, _logout),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final t = tokens(context);
    final l = AppLocalizations.of(context)!;
    const indiceMenu = 2;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _manejarAtras();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Positioned.fill(child: FondoIdentidad()),
            SafeArea(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _tabIndex = i),
                children: [
                  _MantenerVivo(child: InicioScreen(usuarioId: _usuarioId)),
                  _MantenerVivo(
                    child: EstadisticasScreen(activa: _tabIndex == 1),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBarTheme(
          data: barraNavegacionIdentidad(
            identidad(context),
            t,
            Theme.of(context).textTheme.labelMedium,
          ),
          child: NavigationBar(
            // El menú es el tercer destino pero nunca queda seleccionado:
            // no es una página.
            selectedIndex: _tabIndex,
            onDestinationSelected: (i) {
              if (i == indiceMenu) {
                _abrirMenu();
                return;
              }
              _irAPestana(i);
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(LucideIcons.timer),
                label: l.navInicio,
              ),
              NavigationDestination(
                icon: const Icon(LucideIcons.chartColumn),
                label: l.navEstadisticas,
              ),
              NavigationDestination(
                icon: const Icon(LucideIcons.menu),
                label: l.navMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mantiene vivo a su hijo cuando el PageView lo saca de pantalla.
class _MantenerVivo extends StatefulWidget {
  final Widget child;
  const _MantenerVivo({required this.child});

  @override
  State<_MantenerVivo> createState() => _MantenerVivoState();
}

class _MantenerVivoState extends State<_MantenerVivo>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
