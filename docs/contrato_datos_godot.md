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

## 5. Matriz 9×9 de Efectividad Elemental (`multiplicadores_elementales`)
En `data/especies_68.json`, la clave `"multiplicadores_elementales"` se indexa por ID de elemento atacante (`"1".."9"`) y dentro por ID de elemento defensor (`"1".."9"`), con valores `2.0` (crítico), `0.5` (resistente) y `1.0` (neutro), idéntica a `docs/db_y_catalogo.sql`:

| Atacante \ Defensor | 1 Tierra | 2 Fuego | 3 Agua | 4 Planta | 5 Eléctrico | 6 Hielo | 7 Metal | 8 Oscuro | 9 Legendario |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **1. Tierra** | `0.5` | **`2.0`** | `1.0` | `1.0` | **`2.0`** | `1.0` | `1.0` | `1.0` | `1.0` |
| **2. Fuego** | `1.0` | `0.5` | `1.0` | **`2.0`** | `1.0` | **`2.0`** | `1.0` | `1.0` | `1.0` |
| **3. Agua** | **`2.0`** | **`2.0`** | `0.5` | `1.0` | `1.0` | `1.0` | `1.0` | `1.0` | `1.0` |
| **4. Planta** | **`2.0`** | `1.0` | **`2.0`** | `0.5` | `1.0` | `1.0` | `1.0` | `1.0` | `1.0` |
| **5. Eléctrico** | `1.0` | `1.0` | **`2.0`** | `1.0` | `0.5` | `1.0` | **`2.0`** | `1.0` | `1.0` |
| **6. Hielo** | `1.0` | `1.0` | `1.0` | **`2.0`** | **`2.0`** | `0.5` | `1.0` | `1.0` | `1.0` |
| **7. Metal** | `1.0` | `1.0` | `1.0` | `1.0` | `1.0` | **`2.0`** | `0.5` | **`2.0`** | `1.0` |
| **8. Oscuro** | **`2.0`** | `1.0` | `1.0` | `1.0` | `1.0` | `1.0` | **`2.0`** | `0.5` | `1.0` |
| **9. Legendario** | `1.0` | `1.0` | `1.0` | `1.0` | `1.0` | `1.0` | `1.0` | `1.0` | **`2.0`** |

- **Uso en Godot (`GameCore.multiplicadores`):** `float(GameCore.multiplicadores[str(atk_elem_id)][str(def_elem_id)])`.
- **Defensores híbridos (2 elementos):** Se evalúa contra `elemento_primario_id` del defensor (o ambos si el motor aplica combinación multiplicativa; `2.0` = crítico, `0.5` = resistente, `1.0` = neutro).

## 6. Contrato de Combate 1v1 con Relevos, Tienda y Hábitats
- **Movimientos por especie (4 ataques):** Cada dragón en combate dispone de 4 ataques construidos a partir de `elemento_primario_id` y `elemento_secundario_id` (o ataques físicos/especiales si es puro):
  - `{ "nombre": String, "elemento_id": int, "potencia": int, "precision": float }`
  - Ejemplo Puro Tierra (`id = 1`): *Golpe Rocoso* (Tierra, pot. 35), *Embestida* (Neutro/Tierra, pot. 25), *Avalancha* (Tierra, pot. 50), *Terremoto* (Tierra, pot. 65).
- **Estado de unidad en combate 1v1 (equipo de 3):**
  - `active_index` (`0..2`) para aliado y enemigo; los 2 restantes quedan en banca para relevo lateral.
  - Al derrotar al dragón activo rival, entra automáticamente el siguiente disponible hasta derrotar a los 3.
- **Tienda y Hábitats (`savegame.json`):**
  - `estructuras`: cada hábitat guarda `{ "id": int, "island_id": int, "slot_index": int, "elemento_id": int, "oro_acumulado": int }`.
  - `granjas`: `{ "id": int, "island_id": int, "slot_index": int, "nivel": int }`.
  - `dragones`: cada dragón guarda `uid`, `especie_id`, `nivel`, `etapa`, `xp`, `habitat_id`.


