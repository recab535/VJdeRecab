# Base de Diseño del Juego — Sucesor Espiritual de Dragon City (2012)

## 1. Visión y enfoque
- **Concepto:** Juego comercial de crianza, gestión de islas flotantes y combate 1v1 por turnos con equipo de 3 dragones (1 activo + 2 en banca intercambiables) inspirado en el *Dragon City* clásico de 2012 (sencillez, ritmo sin muros de pago abusivos y progresión relevante en batalla).
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

## 9. Combate 1v1 con Relevos (Equipo de 3), Efectividad Elemental y Capítulo 1 PvE (G1)
- **Formato de batalla (estilo Dragon City):**
  - Cada equipo participa con hasta **3 dragones**: **1 dragón activo** en el pedestal 3D y **2 en banca** disponibles para relevo lateral durante la batalla.
  - Cada dragón cuenta con **4 ataques** (según sus elementos y nivel), mostrando en la UI la efectividad (**Fuerte `2.0×`**, **Normal `1.0×`**, **Débil `0.5×`**) frente al rival activo.
  - La victoria se obtiene al derrotar a los 3 dragones del equipo enemigo.
- **Regla de efectividad elemental en combate:**
  - Cada ataque utiliza un elemento del atacante contra el elemento defensor aplicando la matriz `9×9` oficial (`docs/contrato_datos_godot.md`):
    - **Crítico (`2.0`):** Doble daño. Ejemplo inicial: **Tierra (1)** es crítico contra **Fuego (2)** y **Eléctrico (5)**.
    - **Resistente (`0.5`):** Mitad de daño (mismo elemento contra sí mismo, p. ej. Tierra vs Tierra).
    - **Neutro (`1.0`):** Daño estándar para el resto de combinaciones.
- **Capítulo 1 PvE: Sendero Terracota (3 etapas / oleadas):**
  - Diseñado para superarse con el equipo inicial (`Dragón Terracota`, ID `1`) aprovechando la ventaja elemental de Tierra y subiendo de nivel con Comida si es necesario.
  - **Etapa 1 — Vanguardia Ígnea:**
    - **Enemigos:** `Dragón Ascua` (ID `2`, Fuego, Niv. 1) y `Dragón Chispa` (ID `5`, Eléctrico, Niv. 1).
    - **Recompensa:** `150 Oro`, `75 Comida`.
  - **Etapa 2 — Cañón Volcánico:**
    - **Enemigos:** `Dragón Magma` (ID `9`, Tierra/Fuego, Niv. 2) y `Dragón Obsidiana` (ID `10`, Fuego/Tierra, Niv. 2).
    - **Recompensa:** `250 Oro`, `125 Comida`.
  - **Etapa 3 — Guardián del Sendero (Jefe):**
    - **Enemigos (3v3):** `Dragón Terracota` (ID `1`, Tierra, Niv. 2), `Dragón Magma` (ID `9`, Tierra/Fuego, Niv. 3) y `Dragón Ascua` (ID `2`, Fuego, Niv. 3).
    - **Recompensa:** `400 Oro`, `200 Comida`, `5 Gemas` y desbloqueo del **Capítulo 2**.
  - **Total Capítulo 1:** `800 Oro`, `400 Comida` y `5 Gemas`.

## 10. Rediseño UI, Tienda por Categorías y Menú Contextual de Hábitat
- **Tema UI global (`assets/ui/game_theme.tres`):** Paneles y tarjetas con `StyleBoxFlat` redondeados, bordes brillantes, sombras paralelas, barra de nivel de jugador y botones animados con `Tween` al pasar el ratón o clicar.
- **Tienda por pestañas y modo colocación:** Catálogo modal con pestañas (**Hábitats** por elemento con colores propios, **Huevos** y **Granja de Comida**). Al comprar un hábitat se activa el **modo colocación**, iluminando en verde los slots libres de la isla para elegir dónde construir.
- **Vida en la isla y menú contextual de Hábitat:** Decoración low-poly (árboles, rocas, nubes y levitación suave de islas), patrulla autónoma de los dragones dentro de su hábitat con volteo horizontal (`flip_h`) y panel inferior al clicar un hábitat para **Recoger Oro** (con texto flotante) y **Alimentar** dragones con barra de XP y subida de nivel.

## 11. Especificación Definitiva del Producto (5 Islas, Economía, Estructuras y Campaña de 50 Capítulos)
- **Lanzamiento y monetización:**
  - Demo gratuita para **itch.io** como paso previo al lanzamiento en **Steam**.
  - Tienda in-game con pestañas de estructuras/decoración y paquetes preparados/simulados de **Gemas, Oro y Comida**.
- **Flujo de inicio:**
  - Pantalla de carga (`scenes/ui/loading_screen.tscn`) → Tutorial narrativo interactivo con el **Maestro Kael** → Juego principal (`scenes/main.tscn`).
- **Mundo de 5 Islas Consecutivas (eje Z / profundidad isométrica):**
  - Las **5 islas flotantes** se ubican una detrás de otra en profundidad y se desbloquean en orden progresivo mediante **Oro** y **Nivel de jugador**.
  - Cada isla cuenta con una cuadrícula amplia de **14×14 celdas**, dividida en **4 parcelas/porciones** que se adquieren progresivamente con Oro según el nivel de jugador (las bloqueadas aparecen oscurecidas/desvanecidas con vista previa de costo y nivel requerido).
- **Obstáculos temporizados (limpieza con Oro, acelerables con Gemas):**
  | Obstáculo | Tiempo de limpieza | Segundos |
  | :--- | :--- | :---: |
  | Arbusto | 10 min | `600` |
  | Árbol pequeño | 45 min | `2700` |
  | Piedrita | 1 h | `3600` |
  | Árbol grande | 3 h | `10800` |
  | Piedra mediana | 4 h | `14400` |
  | Roca enorme | 8 h | `28800` |
- **Estructuras obligatorias y economía:**
  - **Torre Nido:** Inicia con `1` ranura de huevo; desbloqueo de ranuras adicionales por `10 Gemas` (2.ª), `15 Gemas` (3.ª) y `20 Gemas` (4.ª).
  - **Adoratorio de Cría:** `1` inicial + `1` Adoratorio Extra desbloqueable por `20 Gemas`.
  - **Granjas de Comida:** Producción de comida por tiempo con opción de acelerar con Gemas.
  - **Mina de Gemas:** Máximo `1` por isla (`5` en total). Construirla cuesta `10 Gemas` y genera `1 Gema` cada `24 h` (`86400 s`), permitiendo hasta `5 Gemas/día`.
  - **Coliseo / Portal de Historia:** Estructura en la isla que abre directamente el carrusel horizontal de 50 capítulos.
  - **Campo de Entrenamiento:** Entrena un dragón por tiempo y Oro (acelerable con Gemas) para incrementar permanentemente su rango/estadísticas base de combate.
  - **Guardería / Almacén de Crías:** Reserva de hasta `4` dragoncitos pequeños cuando no hay espacio en hábitats.
  - **Almacén de Estructuras (UI dedicada):** Guarda hasta `5` tipos distintos de estructuras (ampliable con Gemas) y almacenamiento infinito para **diseños de suelo / baldosas decorativas** comprables con Oro.
  - **8 Tótems / Potenciadores Elementales (1 por elemento base, IDs 1..8):** Visibles en Tienda desde nivel 1 a precio de Oro muy elevado. Al colocarse en una isla, duplican (`×2`) permanentemente las estadísticas de dragones de ese elemento; si un híbrido coincide con ambos potenciadores activos, sus estadísticas se triplican (`×3`). Si se guarda en el Almacén, el bono se desactiva. Los 4 Legendarios no reciben potenciador.
- **Nivel de jugador y EXP:**
  - Construir edificios, comprar parcelas, limpiar obstáculos y completar capítulos otorga **EXP de jugador**, subiendo el nivel para desbloquear nuevas parcelas, islas y estructuras.
- **Campaña horizontal de 50 capítulos:**
  - Sin pantalla previa de presentación de rival: al pulsar **Combate** o el **Portal de Historia** se abre un carrusel horizontal (`ScrollContainer`) con los **50 capítulos** (5 por cada uno de los 8 elementos + 10 finales de Legendarios).
  - Cada capítulo exige **1 especie de dragón específica** en el equipo aliado para habilitar el botón *Pelear*, incentivando el uso de todo el catálogo.

## 12. Fusión Definitiva Estilo Clásico 2012 (Implementada)
- **Iluminación y estética orgánica:** Shader `toon_stylized.gdshader` con ruido orgánico continuo (sin césped cuadriculado) y especular controlado para evitar fogonazos blancos al rotar 360°; 5 islas esculpidas irregularmente mediante `SurfaceTool`, sin etiquetas flotantes permanentes en reposo y con enfoque suave de cámara (`Tween`) al clicar cualquier entidad.
- **Grid lógico y entidades vivas:** Matriz `IslandGrid` (`14×14`) con validación `isUnlocked`/`isOccupied`, tamaños coherentes por estructura (`1×1` a `5×5`), modo *Mover* hábitat con rejilla visible solo al colocar/mover, y máquina de estados en `Dragon2D` (`Idle`, `Walk`, `SpecialAnim` + giro de evolución al cambiar de etapa).
- **Cruces con factor misterio:** `Weighted RNG` con bono por nivel de padres, bloqueo de puros opuestos directos, paridad 50%/50% en pares híbridos/opuestos, 4% en recetas legendarias cerradas, sin spoiler previo en el Adoratorio (`Huevo Misterioso ?`) y huevos 3D con banda elemental en la Torre Nido.
- **Ciclo económico y combate 2012:** Tope de oro `HabitatMaxGold` por elemento con moneda flotante limpia (`🪙`), 5 cultivos escalonados de comida (`30 s`, `5 min`, `1 h`, `6 h`, `24 h`), alimentación por pasos (`feed_steps` 0–3 por nivel), y combate 1v1 con fórmulas polinómicas por nivel, `MovePower` entrenable, varianza `0.90–1.10`, rangos `Bronce / Plata / Oro` y `5 %` de fallo.




