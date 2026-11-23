# Contrato de Datos para Godot 4 (G2)

Verificación cruzada entre `docs/db_y_catalogo.sql` y `data/especies_68.json`.

## 1. Catálogo de Elementos (`elementos`)
Cada entrada en el arreglo `"elementos"` de `data/especies_68.json` expone:
- `id` (`int`): 1..9 (1 Tierra, 2 Fuego, 3 Agua, 4 Planta, 5 Eléctrico, 6 Hielo, 7 Metal, 8 Oscuro, 9 Legendario).
- `nombre` (`String`)
- `elemento_opuesto_id` (`int | null`)

## 2. Catálogo de Especies (`especies`)
Cada entrada en el arreglo `"especies"` de `data/especies_68.json` expone los campos exactos que leerá Godot:
- `id` (`int`): Identificador único (`1..68`).
- `nombre` (`String`): Nombre de la especie (ej. `"Dragón Terracota"`).
- `rareza` (`String`): `"PURO"`, `"HIBRIDO"`, `"OPUESTO"` o `"LEGENDARIO"`.
- `elemento_primario_id` (`int`): ID del elemento principal.
- `elemento_secundario_id` (`int | null`): ID del elemento secundario o `null`.
- `elementos` (`Array[int]`): Lista de IDs elementales de la especie (ej. `[1]`).
- `hp_base`, `atk_base`, `spd_base` (`int`): Estadísticas base de combate.
- `oro_por_minuto` (`int`): Producción base en hábitat.
- `tiempo_cria_seg`, `tiempo_incubacion_seg` (`int`): Tiempos base en segundos.
- `sprite_prefijo` (`String`): Prefijo para resolver sprites pixel art 2D (ej. `"dragon_terracota"`).

## 3. Reglas y Matriz
- `reglas_cruce`: `probabilidad_variante_par` (`0.5`), `probabilidad_legendario_defecto` (`0.04`).
- `multiplicadores_elementales`: Diccionario `atacante_id -> { defensor_id: float }`.
