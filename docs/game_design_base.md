# Base de Diseño del Juego — Santuario de Dragones (VJdeRecab)

## 1. Visión y Enfoque
- **Concepto:** Juego comercial de crianza, gestión de islas flotantes y combate **1v1 por turnos con relevos** (equipo de 3 dragones: 1 activo + 2 en banca intercambiables) inspirado en el *Dragon City* clásico de 2012 (sencillez, ritmo sin muros de pago abusivos y progresión relevante en batalla).
- **Lanzamiento y monetización:** Demo gratuita para **itch.io** como paso previo a **Steam**, con tienda in-game y paquetes preparados/simulados de Gemas, Oro y Comida.
- **Identidad original:** Nombres, criaturas, música procedural estéreo y estética artesanal propios.
- **Plataforma y motor:** **Godot 4.7.2** (GDScript). Resolución base **PC (1920×1080)** con escalado adaptable (`canvas_items` / `expand`), preparado para exportación móvil posterior.
- **Coordinación multiagente:** G1 (Diseño/Balance/Campaña), G2 (Datos/Reglas), A1 (Mundo 3D/Cámara/UI/Persistencia) y A2 (Cruces/Campaña/Combate 1v1) sobre `VJdeRecab`.

## 2. Dirección Artística (2.5D) y Experiencia de Usuario
- **Escenarios orgánicos:** 5 islas flotantes consecutivas en profundidad (`eje Z`), esculpidas de forma irregular con `SurfaceTool` y sombreado toon suave (`assets/shaders/toon_stylized.gdshader`) sin césped cuadriculado ni fogonazos especulares al rotar 360°.
- **Nubes y bloqueo de islas:** Nubes ambientales 3D flotando alrededor del archipiélago y un **manto denso de nubes** cubriendo las islas bloqueadas (Islas 2–5). **No se puede explorar, previsualizar ni desbloquear la Isla `N`** hasta haber comprado las **4 parcelas (`0..3`)** de la Isla `N-1`.
- **Cámara y control contextual:** Cámara isométrica orbital con rotación horizontal suave (`Q`/`E`, botones HUD o arrastre derecho), zoom con rueda y enfoque cinematográfico (`Tween`) al clicar cualquier estructura, hábitat, parcela u obstáculo. Al clicar fuera (cielo o espacio vacío), el menú contextual se cierra y la cámara regresa a la vista principal.
- **Tema UI cálido (`assets/ui/game_theme.tres`):** Estética artesanal de fantasía (paneles de madera nogal/caoba, bordes dorados bruñidos, botones ámbar-bronce con animación `Tween` y texto pergamino/marfil). Sin etiquetas flotantes en reposo sobre estructuras.
- **Flujo de inicio:** Pantalla de carga (`scenes/ui/loading_screen.tscn`) → Tutorial narrativo interactivo con el **Maestro Kael** (con flecha guía proyectada dinámicamente en 3D/UI que permanece anclada incluso al rotar la cámara) → Juego principal (`scenes/main.tscn`).
- **Dragones 2D en espacio 3D (`Dragon2D`):** Pixel art con máquina de estados (`Idle`, `Walk`, `SpecialAnim`), sombra proyectada y evolución visual por etapas (`Cría` → `Joven` → `Adulto`).

## 3. Elementos, Catálogo (68 Especies) y Cruces
- **9 Elementos:** 8 base — Tierra (1), Fuego (2), Agua (3), Planta (4), Eléctrico (5), Hielo (6), Metal (7), Oscuro (8) — y 1 especial: Legendario (9).
- **68 Especies (`data/especies_68.json` / `docs/db_y_catalogo.sql`):**
  - **8 Puros** (IDs `1..8`), **48 Híbridos estándar** (24 pares × 2 variantes, IDs `9..56`), **8 Híbridos opuestos** (4 pares antagónicos × 2 variantes, IDs `57..64`) y **4 Legendarios** (recetas cerradas, IDs `65..68`).
- **Reglas de cruce (`Weighted RNG` con factor misterio):**
  - Bloqueo directo de puros opuestos (`1↔5`, `2↔6`, `3↔7`, `4↔8`); requieren cruce mediante híbridos.
  - Paridad `50 % / 50 %` entre variantes `A/B` y `B/A` de cada par híbrido/opuesto, con ligero bono por nivel alto de padres (`>= 10` / `>= 15`).
  - Los 4 Legendarios tienen probabilidad base `4 %` (`0.04`, hasta `0.08` con padres de alto nivel) en recetas cerradas; si falla, se resuelve el cruce normal.
  - En el Adoratorio de Cría se muestra **Huevo Misterioso (`?`)** con rango de tiempos sin revelar previamente la especie resultante; en la Torre Nido se muestran huevos 3D con color primario y banda elemental secundaria.

## 4. Nivel Máximo 30, Templos de Nivel y Balance
- **Nivel máximo 30:** Los dragones escalan del **Nivel 1 al Nivel 30** mediante alimentación clásica en **4 pasos por nivel** (`feed_steps` `0..3`).
- **Etapas evolutivas:**
  - **Cría:** Niveles `1–7`
  - **Joven:** Niveles `8–15`
  - **Adulto:** Niveles `16–30`
- **Progresión por 4 Templos de Nivel (`TemploNivel` en Isla 1 o en Tienda):**
  - Tope inicial sin Templo: **Nv. 10**.
  - **Templo del Alba (Tier 1):** Tope **Nv. 15** (`1500 Oro`, Domador Nv. `3`).
  - **Templo de la Forja (Tier 2):** Tope **Nv. 20** (`4500 Oro`, Domador Nv. `6`).
  - **Templo de las Mareas (Tier 3):** Tope **Nv. 25** (`12000 Oro`, Domador Nv. `10`).
  - **Templo Ancestral (Tier 4):** Tope **Nv. 30** (`30000 Oro`, Domador Nv. `15`).
- **Curvas y multiplicadores balanceados (sin explosión numérica):**
  - Escalado polinómico suave de stats de Nv. 1 a Nv. 30 (`~5.8×` HP y `~5.0×` ATK en Nv. 30 respecto a Nv. 1).
  - **Tótems / Potenciadores Elementales (IDs `1..8`, excluye Legendarios):** **`+20 %`** (`1.20×`) por 1 elemento coincidente y **`+35 %`** (`1.35×`) por 2 elementos en híbridos. Desactivados si se guardan en Almacén.
  - **Campo de Entrenamiento:** Acotado a máximo **`5` rangos** (`+6 %` por rango = hasta **`+30 %`** permanente).
  - **Rangos de Combate por victorias:** **Bronce ★** (`3+` victorias: `+8 %`), **Plata ★★** (`8+`: `+16 %`), **Oro ★★★** (`15+`: `+25 %`).

## 5. Mundo, Cuadrícula, Obstáculos y Estructuras
- **Cuadrícula lógica `IslandGrid` (`14×14` por isla):** Dividida en 4 parcelas (`7×7`). La rejilla solo es visible al construir o mover un hábitat.
- **Obstáculos temporizados (limpieza con Oro, acelerables con Gemas):**
  - Arbusto (`10 min` / `600 s`), Árbol pequeño (`45 min` / `2700 s`), Piedrita (`1 h` / `3600 s`), Árbol grande (`3 h` / `10800 s`), Piedra mediana (`4 h` / `14400 s`), Roca enorme (`8 h` / `28800 s`).
- **Estructuras clave:**
  - **Hábitats Elementales:** Capacidad `2` dragones, generación continua de oro con tope `HabitatMaxGold` por elemento (`500` a `35000 Oro`) e indicador flotante limpio (`🪙`).
  - **Granja de Comida:** 5 cultivos escalonados (`30 s`, `5 min`, `1 h`, `6 h`, `24 h`).
  - **Torre Nido:** `1` ranura inicial, ampliable hasta `4` (`10 / 15 / 20 Gemas`).
  - **Adoratorio de Cría:** `1` inicial + `1` extra (`20 Gemas`).
  - **Mina de Gemas:** Máx. `1` por isla (`10 Gemas` construcción, genera `1 Gema` cada `24 h`).
  - **Campo de Entrenamiento:** Entrenamiento temporizado hasta rango `5/5`.
  - **Guardería de Crías:** Reserva de hasta `4` dragones (accesibles automáticamente en combate si son especie obligatoria).
  - **Templo de Nivel:** Estructura ceremonial en Isla 1 para desbloquear los 4 Templos de Nivel.
  - **Almacén de Estructuras y Baldosas:** Capacidad inicial `5` estructuras (ampliable con Gemas) + inventario infinito de baldosas decorativas.

## 6. Combate 1v1 con Relevos y Campaña PvE de 50 Capítulos
- **Combate 1v1 (equipo de 3):** 1 dragón activo + 2 en banca intercambiables, 4 movimientos por especie, matriz de efectividad elemental `9×9` (`2.0×` crítico, `1.0×` neutro, `0.5×` resistente), varianza `RNG(0.90, 1.10)` y `5 %` de fallo (`¡FALLO!`).
- **Campaña oficial (`data/campana_50.json`):** 50 capítulos en carrusel horizontal (5 por cada elemento base + 10 capítulos Legendarios).
  - Cada capítulo exige **1 especie única obligatoria** (50 especies distintas de las 68 sin duplicados), colocada automáticamente al frente del equipo aunque esté guardada en la Guardería.
  - **Anti-farm de gemas:** Solo la primera victoria en cada capítulo otorga Gemas y recompensa completa; las repeticiones otorgan `0` Gemas y `35 %` de Oro/Comida (`30 %` EXP).

## 7. Persistencia Atómica y Temporizadores Offline
- Persistencia en `user://savegame.json` mediante escritura atómica (`savegame.json.tmp` → `flush`/`close` → `rename`) y respaldo automático `.corrupt.bak` si el JSON estuviera corrupto.
- Todos los procesos temporizados (huevos, granjas, minas de gemas, entrenamiento, limpieza de obstáculos y acumulación de oro de hábitats) almacenan marcas UNIX reales (`end_timestamp` / `last_gold_timestamp`) y se reconcilian al cargar la partida.
- Modo de pruebas limpio controlado por `TEST_CLEAN_START_MODE = true` en `GameCore` sin sobrescribir partidas persistentes.
