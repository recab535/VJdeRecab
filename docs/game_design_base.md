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
- Catálogo estructurado para consumo en Godot 4: `data/especies_68.json`.