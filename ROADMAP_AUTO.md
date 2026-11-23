# Roadmap Autónomo de Desarrollo — VJdeRecab

Plan de tareas incrementales alineado con los roles definidos en `GEMINI.md` (`G1`, `G2`, `A1`, `A2`) y el contrato de datos en `docs/contrato_datos_godot.md`.

- [x] Tarea 1: Implementar el panel UI del Bestiario (`scenes/ui/bestiario_panel.tscn` + script) conectado al botón Bestiario del HUD para mostrar especies descubiertas y bloqueadas.
  - **Rol:** A1 (UI) + A2 (consulta de colección).
  - **Archivos a crear/editar:** Crear `scenes/ui/bestiario_panel.tscn` y `scripts/ui/bestiario_panel.gd`; editar `scenes/main.tscn` y `scripts/main.gd` para instanciar/abrir el panel desde el botón `Bestiario`, leyendo `GameCore.especies_by_id` (`id`, `nombre`, `rareza`, `elementos`, `sprite_prefijo`) y comparando contra `GameCore.player_state["dragones"]`.

- [ ] Tarea 2: Documentar en `docs/game_design_base.md` y `docs/contrato_datos_godot.md` la tabla de efectividad elemental y las 3 etapas del Capítulo 1 PvE (Sendero Terracota).
  - **Rol:** G1 (Diseño/Campaña) + G2 (Datos).
  - **Archivos a crear/editar:** Editar `docs/game_design_base.md` (definición de las 3 oleadas/etapas del Capítulo 1 y recompensas de Oro/Comida) y `docs/contrato_datos_godot.md` (matriz `9×9` de `multiplicadores_elementales`: `2.0` crítico, `0.5` resistente, `1.0` neutro).

- [ ] Tarea 3: Crear la escena 2.5D de la Arena de Combate 3v3 (`scenes/combat/combat_arena.tscn`) con posiciones de equipo aliado/enemigo, barras de HP y botones de ataque.
  - **Rol:** A1 (Escena 2.5D/UI) + A2 (Combate 3v3).
  - **Archivos a crear/editar:** Crear `scenes/combat/combat_arena.tscn` y `scripts/combat/combat_arena.gd` con 3 marcadores aliados, 3 enemigos (`Dragon2D`), barras de HP por unidad y panel inferior con botones de ataque elemental.

- [ ] Tarea 4: Implementar el motor de combate por turnos (`scripts/systems/combat_manager.gd`) usando `hp_base`, `atk_base`, `spd_base` y ventajas elementales, conectado al botón Combate del HUD y otorgando recompensas al ganar el Capítulo 1.
  - **Rol:** A2 (Sistemas de Combate y Campaña).
  - **Archivos a crear/editar:** Crear `scripts/systems/combat_manager.gd`; editar `scripts/autoload/game_core.gd` (método para acreditar recompensas y avanzar `capitulo_pve_actual` en `user://savegame.json`) y `scripts/main.gd` / `scenes/combat/combat_arena.tscn` para lanzar el Capítulo 1 desde el botón `Combate`.

- [ ] Tarea 5: Hacer funcional el botón Desbloquear de Isla 2 (Bruma Volcánica, 2500 Oro) en `locked_island.gd` y `GameCore`, habilitando 4 nuevos slots construibles en la segunda isla.
  - **Rol:** A1 (Mundo 3D/HUD) + A2 (Persistencia).
  - **Archivos a crear/editar:** Editar `scripts/world/locked_island.gd`, `scripts/autoload/game_core.gd` (método `unlock_island(island_id, cost_oro)` actualizando `islas_desbloqueadas`), `scenes/main.tscn` (añadir `SlotsConstruibles` en Isla 2 y material desbloqueado) y `scripts/main.gd`.

- [ ] Tarea 6: Implementar el sistema de alimentación con Comida en `GameCore` y en el hábitat/dragón para subir de nivel a los dragones y aumentar sus estadísticas y oro por minuto.
  - **Rol:** A2 (Progresión) + A1 (UI/Hábitat).
  - **Archivos a crear/editar:** Editar `scripts/autoload/game_core.gd` (método `feed_dragon(dragon_uid)` descontando `Comida` y actualizando `nivel`/`etapa` en `savegame.json`), `scripts/world/habitat_base.gd` y `scripts/ui/hud_basic.gd` / `scripts/main.gd` para disparar y mostrar la subida de nivel.

- [ ] Tarea 7: Ampliar el generador visual procedural en `dragon_2d.gd` para diferenciar colores, formas y detalles pixel art únicos para los 8 elementos puros (IDs 1 al 8).
  - **Rol:** A2 (Entidades 2D `Sprite3D`).
  - **Archivos a crear/editar:** Editar `scripts/dragons/dragon_2d.gd` en `_create_placeholder_pixel_art(id)` añadiendo paletas y siluetas/detalles diferenciados (cuernos, llamas, aletas, hojas, rayos, cristales, placas metálicas y aura oscura) para los IDs `1..8`.

- [ ] Tarea 8: Implementar un selector visual de especies en los botones Cruce y Nido para elegir qué dos dragones cruzar y ver el tiempo/estado de incubación.
  - **Rol:** A1 (UI) + A2 (Cruces/Nido).
  - **Archivos a crear/editar:** Crear `scenes/ui/breeding_panel.tscn`, `scripts/ui/breeding_panel.gd`, `scenes/ui/nest_panel.tscn` y `scripts/ui/nest_panel.gd`; editar `scenes/main.tscn`, `scripts/main.gd` y `scripts/autoload/game_core.gd` para seleccionar padres disponibles y mostrar el progreso de `nido_huevos`.
