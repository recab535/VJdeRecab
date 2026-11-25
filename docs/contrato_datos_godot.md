# Contrato de Datos para Godot 4 (G2)

Verificación cruzada oficial entre `docs/db_y_catalogo.sql`, `data/especies_68.json`, `data/campana_50.json` y `scripts/autoload/game_core.gd`.

## 1. Catálogo de Elementos y Especies (`data/especies_68.json`)
- **`elementos` (`1..9`):** `id` (`int`), `nombre` (`String`), `elemento_opuesto_id` (`int | null`).
  - Opuestos: `1↔5` (Tierra/Eléctrico), `2↔6` (Fuego/Hielo), `3↔7` (Agua/Metal), `4↔8` (Planta/Oscuro).
- **`especies` (`1..68`):** `id`, `nombre`, `rareza` (`"PURO" | "HIBRIDO" | "OPUESTO" | "LEGENDARIO"`), `elemento_primario_id`, `elemento_secundario_id`, `elementos`, `hp_base`, `atk_base`, `spd_base`, `oro_por_minuto`, `tiempo_cria_seg`, `tiempo_incubacion_seg`, `sprite_prefijo`.
- **`reglas_cruce`:** `probabilidad_variante_par` (`0.5`), `probabilidad_legendario_defecto` (`0.04`).
- **`recetas_legendarias`:**
  - `57` (Sísmico) + `59` (Piroescarcha) → **`65` (Dragón Éter)** (`0.04`)
  - `61` (Mercurio) + `63` (Marchito) → **`66` (Dragón Prisma)** (`0.04`)
  - `58` (Telúrico) + `62` (Hidrometal) → **`67` (Dragón Cronos)** (`0.04`)
  - `60` (Termozero) + `64` (Espina Negra) → **`68` (Dragón Astral)** (`0.04`)

## 2. Matriz 9×9 de Efectividad Elemental (`multiplicadores_elementales`)
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

## 3. Campaña Oficial de 50 Capítulos (`data/campana_50.json`)
Estructura raíz:
- `version` (`String`), `total_capitulos` (`50`), `capitulos` (`Array[Dictionary]`).
- Cada capítulo expone:
  - `capitulo` (`1..50`), `titulo` (`String`), `arco` (`String`), `elemento_id` (`1..9`), `especie_requerida_id` (`int`, **50 especies únicas sin duplicados**).
  - Recompensas de 1.ª victoria: `oro`, `comida`, `gemas`, `exp`.
  - `enemigos`: `Array[{ "especie_id": int, "nivel": int }]` (3 rivales por capítulo, escalando de `Nv.1` en Cap. 1 hasta `Nv.30` en Cap. 50).
- **Regla anti-farm en repeticiones:** Si `capitulo` ya existe en `player_state["campana"]["completados"]`, `complete_campaign_chapter()` acredita `gemas = 0`, `oro * 0.35`, `comida * 0.35`, `exp * 0.30` y devuelve `"first_clear": false`.

## 4. Nivel Máximo 30, Templos de Nivel y Fórmulas de Balance
- **Constantes en `GameCore`:**
  - `MAX_DRAGON_LEVEL = 30`, `BASE_DRAGON_LEVEL_CAP = 10`, `MAX_TRAINING_LEVEL = 5`, `TRAINING_BONUS_PER_LEVEL = 0.06`.
- **Etapas evolutivas (`get_stage_for_level`):**
  - `1..7`: `"cria"` | `8..15`: `"joven"` | `16..30`: `"adulto"`.
- **Templos de Nivel (`LEVEL_TEMPLES`):**
  | Tier | Nombre | Tope Nivel | Costo Oro | Nivel Domador | EXP |
  | :---: | :--- | :---: | :---: | :---: | :---: |
  | `1` | Templo del Alba | `15` | `1500` | `3` | `90` |
  | `2` | Templo de la Forja | `20` | `4500` | `6` | `160` |
  | `3` | Templo de las Mareas | `25` | `12000` | `10` | `260` |
  | `4` | Templo Ancestral | `30` | `30000` | `15` | `400` |
- **Fórmulas de estadísticas (`get_dragon_stats`, para `d_lvl = nivel - 1` con `nivel` en `1..30`):**
  - `hp_poly = 1.0 + 0.085 * d_lvl + 0.0028 * d_lvl²`
  - `atk_poly = 1.0 + 0.075 * d_lvl + 0.0022 * d_lvl²`
  - `spd_poly = 1.0 + 0.035 * d_lvl`
  - **Entrenamiento:** `train_mult = 1.0 + clamp(entrenamiento_nivel, 0, 5) * 0.06` (máx. `1.30×`).
  - **Tótems elementales (excluye Legendarios):** `1.00×` (`0` elem.), **`1.20×`** (`1` elem.), **`1.35×`** (`2` elems. en híbrido).
  - **Rangos de combate (`victorias_combate`):** `1.00×` (`0..2`), **Bronce ★ `1.08×`** (`3..7`), **Plata ★★ `1.16×`** (`8..14`), **Oro ★★★ `1.25×`** (`15+`).
  - `hp = round(hp_base * hp_poly * train_mult * booster_mult * rank_mult)`
  - `atk = round(atk_base * atk_poly * train_mult * booster_mult * rank_mult)`
  - `spd = round(spd_base * spd_poly * train_mult)`
- **Fórmula de daño en combate 1v1 (`CombatManager`):**
  - `5 %` de fallo (`missed = true`).
  - `daño = max(10, round(atk * (move_power / 40.0) * elemental_mult * RNG(0.90, 1.10)))`.
- **Alimentación (4 pasos por nivel, `feed_steps` `0..3`):**
  - `costo_paso = max(15, round(14.0 + d_lvl * 18.0 + d_lvl² * 2.2))`.
- **Oro/minuto por dragón:** `oro_base * (1.0 + d_lvl * 0.14)`, acotado por `HABITAT_MAX_GOLD` (`500` a `35000`).

## 5. Persistencia Atómica (`user://savegame.json`) y Marcas Offline
- **Guardado atómico (`save_game_to_path`):** Escribe en `<path>.tmp`, hace `flush()` + `close()` y reemplaza atómicamente vía `DirAccess.rename_absolute`.
- **Respaldo de corrupción (`load_game_from_path`):** Si el JSON falla al parsear o no es `Dictionary`, crea copia de respaldo en `<path>.corrupt.bak` antes de restaurar estado por defecto.
- **Modo pruebas limpio:** `TEST_CLEAN_START_MODE = true` inicia limpio sin alterar `user://savegame.json`.
- **UID global único:** `_get_next_dragon_uid()` inspecciona tanto `dragones` como `guarderia` para evitar colisiones de `uid`.
- **Dragón obligatorio en combate:** `get_all_owned_dragons()` combina `dragones` y `guarderia`; `CombatManager._build_teams()` coloca la copia de mayor nivel de `especie_requerida_id` como líder activo.
- **Regla de avance de islas:** `can_explore_island(N)` exige que la Isla `N-1` esté desbloqueada y tenga sus **4 parcelas (`0..3`)** compradas (`are_all_parcels_unlocked(N-1)`).
- **Claves raíz persistidas:**
  - `version`, `nivel_jugador`, `exp_jugador`, `capitulo_pve_actual`, `tutorial_completado`, `recursos` (`oro`, `comida`, `gemas`).
  - `islas_desbloqueadas`, `parcelas_desbloqueadas`, `templos_nivel` (`Array[int]` con tiers `1..4`).
  - `estructuras`: `{ "id", "slot_index", "elemento_id", "oro_acumulado", "last_gold_timestamp" }`.
  - `nido_huevos`: `{ "especie_id", "nombre", "tiempo_incubacion_seg", "tiempo_restante_seg", "end_timestamp", "listo" }`.
  - `obstaculos`, `minas_gemas`, `granjas_comida`, `entrenamiento`: incluyen `end_timestamp` (segundos UNIX) reconciliado automáticamente en `reconcile_offline_timers()` al cargar.
  - `dragones`, `guarderia`, `almacen`, `potenciadores_colocados`, `campana` (`capitulo_desbloqueado`, `completados`).
