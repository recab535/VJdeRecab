# Base de Diseño del Juego — Sucesor Espiritual de Dragon City (2012)

## 1. Visión y enfoque
- **Concepto:** Juego comercial de crianza, gestión de islas flotantes y combate 3v3 por turnos inspirado en el *Dragon City* clásico de 2012 (sencillez, ritmo sin muros de pago abusivos y progresión relevante en batalla).
- **Identidad original:** Nombres, criaturas, música y estética propios para constituir una propiedad intelectual original viable comercialmente.
- **Plataforma y motor:** **Godot 4** (GDScript). Prioridad inicial en **PC (1920×1080)** y preparación para exportar a **móvil** en una etapa posterior.
- **Trabajo en conjunto:** Coordinación entre **Gemini** (G1: Diseño/Balance/Campaña; G2: Arquitectura de Datos/Reglas) y **Antigravity** (A1: Mundo 3D/Cámara/UI/Persistencia; A2: Cruces/Campaña/Combate 3v3) sobre el repositorio `VJdeRecab`.

## 2. Dirección artística (2.5D)
- **Escenarios:** Islas flotantes en **3D minimalista / low-poly vibrante**, con sombreado limpio, paletas saturadas y movimiento ambiental.
- **Islas bloqueadas:** Más oscuras o desvanecidas; al clicar o tocar se muestra una vista previa de los espacios disponibles para desbloquear.
- **Rotación y cámara:** Cámara con vista isométrica/inclinada y botones en pantalla para rotar el ángulo horizontal de la isla, además de arrastre y zoom.
- **Dragones:** Sprites en **pixel art 2D** dentro de los hábitats, integrados en escala y proyección de sombras sobre el terreno 3D.
- **Interfaz (HUD):** Resolución base `1920×1080` con escalado adaptable, recursos en esquina superior izquierda y accesos principales (Tienda, Cruce, Nido/Incubación, Bestiario, Combate) más botones de rotación.

## 3. Elementos, catálogo y cruces
- **Elementos (9 en total):**
  - 8 elementos base: Tierra (1), Fuego (2), Agua (3), Planta (4), Eléctrico (5), Hielo (6), Metal (7), Oscuro (8).
  - 1 elemento especial: Legendario (9).
- **Catálogo (68 especies):**
  - **8 Puros** (1 elemento).
  - **48 Híbridos estándar** (24 pares compatibles × 2 variantes A/B y B/A).
  - **8 Híbridos opuestos** (4 pares antagónicos × 2 variantes A/B y B/A, vía híbridos).
  - **4 Legendarios** (recetas cerradas).
- **Reglas de cruce:**
  - En pares híbridos válidos, **50 % / 50 %** entre las dos variantes del par.
  - Los 4 Legendarios tienen probabilidad base baja (**4 %**, `0.04`) en sus recetas específicas; si no sale el legendario, se resuelve el cruce normal entre padres.

## 4. Progresión, campaña y endgame
- **Campaña PvE:** **50 capítulos** en total (5 capítulos por cada uno de los 8 elementos base + 10 capítulos finales centrados en Legendarios).
- **Recompensas de capítulos:** Desbloqueo de elementos/islas/estructuras, catalizadores de etapa evolutiva (Cría / Joven / Adulto) y recursos/mejoras para potenciar dragones.
- **Post-campaña y Ligas Superiores:** Al completar la campaña PvE se habilitan las **Ligas Superiores** y mecánicas de *endgame* (variantes cromáticas, desafíos con restricciones, expediciones/reliquias, temporadas y aspectos ambientales).

## 5. Fuente de datos
- Esquema y poblado SQL de referencia: `docs/db_y_catalogo.sql`.
- Catálogo estructurado para consumo en Godot 4: `data/especies_68.json` (incluye `sprite_prefijo` por especie para resolver sprites 2D).
- Persistencia local del jugador: `user://savegame.json` (estado de islas, estructuras/hábitats, recursos, colección e inventario).

## 6. Organización del proyecto en Godot 4 y límites de equipo
Estructura de carpetas respetando la base existente (`assets/`, `data/`, `docs/`, `scenes/`, `scripts/`):

- `project.godot` en la raíz, con resolución base `1920×1080` (`stretch/mode = canvas_items`, `stretch/aspect = expand`).
- `assets/`
  - `assets/sprites/dragons/` (pixel art 2D indexado por `sprite_prefijo` y etapa: cria/joven/adulto)
  - `assets/sprites/ui/` (iconos de recursos, elementos, botones)
  - `assets/materials/` y `assets/models/` (materiales low-poly y recursos 3D de islas/hábitats)
  - `assets/audio/` (música y efectos)
- `data/`
  - `especies_68.json` (catálogo oficial) y futuros JSON de campaña/ligas (G2)
- `scenes/`
  - `scenes/main.tscn` (escena principal arrancable con `F5`)
  - `scenes/world/` (islas flotantes 3D, cámara orbital/isométrica, hábitats, preview de islas bloqueadas) — **A1**
  - `scenes/dragons/` (entidad visual 2D en espacio 3D `Sprite3D` + sombra proyectada) — **A1**
  - `scenes/ui/` (HUD `1920×1080`, paneles de tienda/bestiario/vista previa) — **A1**
  - `scenes/systems/` o `scenes/combat/` (escenas de cruce, campaña y combate 3v3) — **A2**
- `scripts/`
  - `scripts/autoload/` (`SaveManager.gd`, `GameState.gd` / `CatalogLoader.gd`) — **A1** (datos compartidos con **A2**)
  - `scripts/world/` (rotación horizontal, cámara, interacción con islas/hábitats) — **A1**
  - `scripts/ui/` (controladores del HUD) — **A1**
  - `scripts/systems/` (motor de cruces, campaña PvE de 50 capítulos, combate 3v3) — **A2**

## 7. Especificaciones de la escena principal y Capítulo 1 PvE (G1)
- **Isla inicial (Isla Santuario):**
  - Plataforma flotante 3D low-poly centrada en `(0, 0, 0)` con superficie verde/tierra y base rocosa minimalista, iluminada con `DirectionalLight3D` y `WorldEnvironment` vibrante.
  - Espacio inicial preparado para colocar el primer hábitat y dragones 2D (`Sprite3D` con sombra).
  - Las islas vecinas bloqueadas se muestran más oscuras/desvanecidas y permiten previsualizar sus espacios al clicar.
- **Cámara y rotación horizontal:**
  - `CameraRig` (`Node3D` pivote en `(0, 0, 0)`) con `Camera3D` en ángulo inclinado/isométrico.
  - Rotación horizontal suave (interpolada) controlada por botones en HUD (`Rotar Izq` `-45°` / `Rotar Der` `+45°`) y teclas (`Q`/`E` o flechas), más zoom con rueda del ratón.
- **HUD básico (`1920×1080`):**
  - **Superior izquierda:** Recursos iniciales (`Oro`, `Comida`, `Gemas`) y nivel del jugador.
  - **Inferior derecha:** Botones de rotación horizontal (`↺ Izq`, `↻ Der`).
  - **Inferior centro:** Botones principales (`Tienda`, `Cruce`, `Nido`, `Bestiario`, `Combate`).
- **Flujo del Capítulo 1 PvE (Elemento Tierra):**
  - El jugador inicia con `Dragón Terracota` (ID `1`, Puro Tierra) y recursos base (`1000` Oro, `500` Comida, `25` Gemas).
  - Desde `Combate` accede al **Capítulo 1: Sendero Terracota** (1 de 5 capítulos de Tierra).
  - Al superar el combate del Capítulo 1, recibe recompensa de Oro/Comida y desbloquea el Capítulo 2.

## 8. Hábitats, vista previa de islas bloqueadas y flujo de Cruce + Nido (G1)
- **Construcción de hábitats (desde Tienda):**
  - **Hábitat Base (Nivel 1):** Costo inicial `250 Oro`, capacidad para **2 dragones** compatibles con su elemento.
  - **Generación pasiva de oro:** Cada dragón alojado aporta su `oro_por_minuto` (definido en `especies_68.json`, ej. `12 Oro/min` para `Dragón Terracota`), acumulándose de forma continua y acreditándose al jugador de forma periódica o al recolectar.
  - **Marcadores construibles:** Cada isla dispone de puntos de anclaje (`Slot_1`, `Slot_2`, etc.) donde se instancian los hábitats comprados.
- **Vista previa al clicar islas bloqueadas:**
  - Al hacer clic sobre una isla bloqueada (oscura/desvanecida), se abre un panel emergente con:
    - Nombre de la isla, cantidad de espacios construibles disponibles y elementos recomendados.
    - Costo de desbloqueo en Oro/Gemas (ej. `2500 Oro` para la Isla 2) y botón de acción (deshabilitado si no alcanza el recurso o requisito).
- **Flujo básico de Cruce + Incubación en el Nido:**
  - **Cruce:** El jugador selecciona 2 dragones adultos disponibles desde el panel `Cruce`; al confirmar, se resuelve la especie resultante según las reglas de cruce y se envía un huevo al **Nido**.
  - **Nido (Incubación):** El huevo permanece en incubación durante `tiempo_incubacion_seg` (acelerable en prototipo o completado al vencer el temporizador) y al eclosionar se añade el nuevo dragón a la colección del jugador (`savegame.json`) para ubicarlo en un hábitat con espacio libre.


