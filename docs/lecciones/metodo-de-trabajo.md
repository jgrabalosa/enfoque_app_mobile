# Lecciones: método de trabajo

_Sacado del `CLAUDE.md` el 24-nov-2026 para que no pase de 200 líneas (D-38 del proyecto: lo que sale va a `docs/`). El `CLAUDE.md` dice cuándo leer este fichero._

### Método de trabajo (vale para los cinco repos)

- **La primera línea de un prompt se comprueba, no se recuerda.** Son cinco
  repos: cuatro están en `C:\Dev\Norday\` (`habitos-app`,
  `habitos_app_mobile`, `norday_flutter_core` y este, `enfoque_app_mobile`)
  y `conocimiento_app_mobile` está en `C:\Dev\Conocimiento\`.
- **Un solo agente por repo a la vez.** Todo lo que haga otro agente se
  revisa en el remoto antes de mergear.
- **Las cifras de verificación se cuentan contra el repositorio**, nunca se
  copian del roadmap. Y son cifras exactas, no adjetivos.
- **Un filtro que no encuentra nada no es un resultado.** Ante una salida
  vacía, mirar la fuente completa antes de concluir.
- **Al sustituir un bloque, incluir el comentario de encima.**
- **Mirar dónde se pega cada bloque.** Un bloque para la máquina local,
  lanzado en el VPS, llegó a `git push` y pidió credenciales.
- **`git diff` y `git log` abren paginador**: `git --no-pager`.
- **Antes de `git tag`, `git --no-pager log -1`.**
- **Un tag anotado resuelve a su commit, no a sí mismo**:
  `git rev-parse <tag>^{commit}`.
- **PowerShell 5.1 lee los `.ps1` sin BOM como ANSI**: scripts sin acentos, o
  guardados con BOM.
