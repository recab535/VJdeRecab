# GEMINI.md - Protocolo y Roles Multiagente (Proyecto VIDEOJUEGO)

## 1. Roles y Responsabilidades de los Agentes
- **G1 (Diseño / Balance / Campaña):** Encargado de la definición de diseño de juego, balance numérico (nivel máximo 30 con Templos de Nivel, curvas polinómicas y economía) y estructura de la campaña PvE de 50 capítulos (en `docs/` y `data/campana_50.json`).
- **G2 (Arquitectura de Datos / Reglas):** Encargado del esquema y poblado SQL de referencia (`docs/db_y_catalogo.sql`), el catálogo oficial de 68 especies (`data/especies_68.json`), el archivo de campaña (`data/campana_50.json`) y el contrato de datos (`docs/contrato_datos_godot.md`).
- **A1 (Mundo 3D / Cámara / UI / Persistencia):** Encargado de las escenas 2.5D en Godot 4 (`1920×1080`), 5 islas flotantes orgánicas low-poly con nubes 3D y 4 parcelas por isla, cámara orbital con enfoque suave (`Tween`), tema cálido de fantasía (`assets/ui/game_theme.tres`), tutorial interactivo con flecha guía dinámica y persistencia atómica con temporizadores offline (`user://savegame.json`).
- **A2 (Cruces / Campaña / Combate 1v1 con Relevos):** Encargado del motor de cruces con factor misterio (`Weighted RNG`), la progresión de campaña de 50 capítulos (dragón obligatorio desde hábitats o Guardería, sin gemas infinitas al repetir), el sistema de combate 1v1 por turnos con equipo de 3 (1 activo + 2 en banca) y la integración de entidades de dragones 2D (`Sprite3D` con máquina de estados).

## 2. Protocolo de Turnos y Sincronización
- El estado de ejecución y rotación se gestiona mediante el archivo raíz `ESTADO_AGENTES.json`.
- Orden cíclico de turnos: `G1` -> `G2` -> `A1` -> `A2`.
- Cada agente lee el estado actual, ejecuta su contribución sobre su dominio asignado, valida en Godot 4 headless sin errores ni advertencias, actualiza `ESTADO_AGENTES.json` y avanza al siguiente turno.
