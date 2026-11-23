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

## 4. Tabla de Reglas de Cruce y Recetas Cerradas
| Tipo de resultado | Condición de padres | Probabilidad | Notas |
| :--- | :--- | :--- | :--- |
| **Puros (8)** | Mismo elemento único (`E1 + E1`) | `100 %` (`1.0`) | Produce el Puro de ese elemento (IDs `1..8`). |
| **Híbridos estándar (48)** | Dos elementos distintos compatibles (`A + B`) | `50 % / 50 %` (`0.5`) | Entre variante `A/B` y `B/A` del par (IDs `9..56`). |
| **Híbridos opuestos (8)** | Elementos antagónicos (`1↔5`, `2↔6`, `3↔7`, `4↔8`) vía híbridos | `50 % / 50 %` (`0.5`) | Entre variante `A/B` y `B/A` del par opuesto (IDs `57..64`). |
| **Legendarios (4)** | Recetas cerradas específicas | `4 %` (`0.04`) | Si falla el 4 %, se resuelve el cruce normal entre padres. |

### Recetas cerradas de Legendarios (`recetas_legendarias`)
| Padre A (ID) | Padre B (ID) | Legendario resultante (ID) | Probabilidad |
| :--- | :--- | :--- | :--- |
| Dragón Sísmico (`57`) | Dragón Piroescarcha (`59`) | **Dragón Éter** (`65`) | `0.04` (4 %) |
| Dragón Mercurio (`61`) | Dragón Marchito (`63`) | **Dragón Prisma** (`66`) | `0.04` (4 %) |
| Dragón Telúrico (`58`) | Dragón Hidrometal (`62`) | **Dragón Cronos** (`67`) | `0.04` (4 %) |
| Dragón Termozero (`60`) | Dragón Espina Negra (`64`) | **Dragón Astral** (`68`) | `0.04` (4 %) |
