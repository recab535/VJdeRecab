# GEMINI.md - Protocolo y Roles Multiagente (Proyecto VIDEOJUEGO)

## 1. Roles y Responsabilidades de los Agentes
- **G1 (Diseño / Balance / Campaña):** Encargado de la definición de diseño de juego, balance numérico y estructura de la campaña PvE (en `docs/`).
- **G2 (Arquitectura de Datos / Reglas):** Encargado del esquema y poblado SQL de referencia (`docs/db_y_catalogo.sql`) y la estructura de datos oficial (`data/especies_68.json`).
- **A1 (Mundo 3D / Cámara / UI / Persistencia):** Encargado de las escenas 2.5D en Godot 4, islas flotantes low-poly, gestión de cámara, interfaz HUD y persistencia (`user://savegame.json`).
- **A2 (Cruces / Campaña / Combate 3v3):** Encargado del motor de cruces, la progresión de campaña de 50 capítulos, el sistema de combate por turnos 3v3 y la integración de entidades de dragones 2D (`Sprite3D`).

## 2. Protocolo de Turnos y Sincronización
- El estado de ejecución y rotación se gestiona mediante el archivo raíz `ESTADO_AGENTES.json`.
- Orden cíclico de turnos: `G1` -> `G2` -> `A1` -> `A2`.
- Cada agente lee el estado actual, ejecuta su contribución sobre su dominio asignado, actualiza `ESTADO_AGENTES.json` y avanza al siguiente turno.
