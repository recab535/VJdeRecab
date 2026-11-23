# Especificación de Campaña, Progresión y Balance (G1 — Diseño / Balance / Campaña)

Este documento define las reglas oficiales de balance numérico, progresión de etapas, estructura de recompensas y desbloqueos de los **50 capítulos de la campaña PvE**, así como la transición hacia las **Ligas Superiores** y el **Endgame** del sucesor espiritual de *Dragon City* (2012).

> **Nota de coordinación:** Las tablas e IDs de este documento están alineados con `docs/db_y_catalogo.sql` y `data/especies_68.json` (G2) para su implementación directa en Godot 4 (A1 / A2).

---

## 1. Matriz Elemental y Sistema de Combate 3v3

El combate se realiza por turnos en equipos de **3 vs 3 dragones**, ordenados por velocidad (`spd_base` escalado). Cada dragón posee un **Elemento Primario** (`elemento_primario_id`) y, en el caso de híbridos y opuestos, un **Elemento Secundario** (`elemento_secundario_id`).

### 1.1 Matriz Oficial de Ventajas Elementales (9×9)
Alineada exactamente con `multiplicadores_elementales` de `docs/db_y_catalogo.sql` y `data/especies_68.json`:
- **Crítico / Super Efectivo (`×2.0`)**
- **Resistente / Mismo Elemento (`×0.5`)**
- **Neutro (`×1.0`)**

| ID | Elemento | Hace `×2.0` a | Hace `×0.5` a | Recibe `×2.0` de |
| :---: | :--- | :--- | :--- | :--- |
| **1** | **Tierra** | Fuego (2), Eléctrico (5) | Tierra (1) | Agua (3), Planta (4), Oscuro (8) |
| **2** | **Fuego** | Planta (4), Hielo (6) | Fuego (2) | Tierra (1), Agua (3) |
| **3** | **Agua** | Tierra (1), Fuego (2) | Agua (3) | Planta (4), Eléctrico (5) |
| **4** | **Planta** | Tierra (1), Agua (3) | Planta (4) | Fuego (2), Hielo (6) |
| **5** | **Eléctrico** | Agua (3), Metal (7) | Eléctrico (5) | Tierra (1), Hielo (6) |
| **6** | **Hielo** | Planta (4), Eléctrico (5) | Hielo (6) | Fuego (2), Metal (7) |
| **7** | **Metal** | Hielo (6), Oscuro (8) | Metal (7) | Eléctrico (5), Oscuro (8) |
| **8** | **Oscuro** | Tierra (1), Metal (7) | Oscuro (8) | Metal (7) |
| **9** | **Legendario** | Legendario (9) | *(Ninguno — `×1.0` vs 1..8)* | Legendario (9) |

---

## 2. Estadísticas, Etapas Evolutivas y Catalizadores

### 2.1 Escala de Niveles y Etapas (Cría / Joven / Adulto)
Cada dragón progresa del **Nivel 1 al Nivel 30** (en campaña; extensible en endgame). La evolución visual (`sprite_prefijo` + etapa) y el desbloqueo del techo de nivel están ligados a **Catalizadores de Etapa**:

| Etapa | Rango de Nivel | Requisito de Evolución | Bonificación de Etapa |
| :--- | :---: | :--- | :--- |
| **Cría** | `1 – 10` | Ninguno (estado inicial al eclosionar) | Stats base (`×1.00`) + 1 habilidad básica |
| **Joven** | `11 – 20` | **Catalizador Joven** + alcanzar Nv. 10 | `+15%` HP/ATK/SPD adicional + 2.ª habilidad elemental |
| **Adulto** | `21 – 30` | **Catalizador Adulto** + alcanzar Nv. 20 | `+25%` HP/ATK/SPD adicional + habilidad definitiva / pasiva |

> **Regla de diseño (Anti-Muro de Pago):** Los catalizadores **nunca** bloquean al jugador tras compras premium obligatorias. El primer Catalizador Joven se entrega en el **Capítulo 5** y el primer Catalizador Adulto en el **Capítulo 20**, garantizando el avance fluido del equipo principal.

### 2.2 Crecimiento por Rareza y Fórmula de Combate (para A2)
Usando los campos oficiales de `data/especies_68.json` (`hp_base`, `atk_base`, `spd_base`):

| Rareza | Crecimiento por Nivel | Multiplicador Etapa Joven | Multiplicador Etapa Adulto |
| :--- | :---: | :---: | :---: |
| **PURO** | `+8%` por nivel sobre base | `×1.15` | `×1.25` |
| **HIBRIDO** | `+9%` por nivel sobre base | `×1.15` | `×1.25` |
| **OPUESTO** | `+10%` por nivel sobre base | `×1.15` | `×1.25` |
| **LEGENDARIO** | `+12%` por nivel sobre base | `×1.15` | `×1.25` |

$$\text{Stat}(L) = \text{Stat}_{\text{base}} \times \big(1 + \text{Crecimiento} \times (L - 1)\big) \times \text{Mult}_{\text{etapa}}$$

$$\text{Daño Final} = \max\left(10,\ \text{ATK}_{\text{atacante}} \times \text{Poder}_{\text{habilidad}} \times \text{Mult}_{\text{elemental}} \times \text{Aleatorio}(0.95,\ 1.05)\right)$$

*(Nota: Al no existir `def_base` en `especies_68.json`, la supervivencia se balancea mediante `hp_base` —donde tanques como Tierra/Metal tienen `420–445` HP base frente a `310–335` de atacantes rápidos— y el multiplicador elemental `0.5 / 1.0 / 2.0`).*

---

## 3. Estructura Detallada de los 50 Capítulos PvE (Bloques, Recompensas y Desbloqueos)

La campaña consta de **50 capítulos**: **8 bloques elementales** (5 capítulos por elemento = Caps 1–40) + **2 bloques de Legendarios** (10 capítulos finales = Caps 41–50).

- **Capítulos normales** (ej. 1–4, 6–9, etc.): Otorgan **Oro**, **Comida** y **XP de jugador**.
- **Capítulos Jefe de Bloque** (múltiplos de 5: **5, 10, 15, 20, 25, 30, 35, 40, 45, 50**): Otorgan recompensas clave de progresión (desbloqueo de elemento, hábitat, isla flotante, catalizadores de etapa y accesos de sistema).

### 3.1 Resumen por Bloques e Hitos Clave

| Bloque | Capítulos | Elemento / Foco | Nivel Enemigo | Isla Asociada (A1) | Hito Principal de Desbloqueo (Jefe de Bloque) |
| :---: | :---: | :--- | :---: | :--- | :--- |
| **B1** | `1 – 5` | **Tierra (1)** | `1 – 5` | **Isla 1: Pradera Terracota** *(Inicial)* | Tutorial 3v3, **1.er Catalizador Joven**, desbloqueo **Elemento Fuego** |
| **B2** | `6 – 10` | **Fuego (2)** | `5 – 8` | Isla 1: Pradera Terracota | **2.º Catalizador Joven**, **Isla 2: Archipiélago Marea**, **Elemento Agua** |
| **B3** | `11 – 15` | **Agua (3)** | `8 – 11` | **Isla 2: Archipiélago Marea** | **3.er Catalizador Joven**, Tienda de Catalizadores Joven, **Elemento Planta** |
| **B4** | `16 – 20` | **Planta (4)** | `11 – 14` | Isla 2: Archipiélago Marea | **1.er Catalizador Adulto**, mejora Granja Nv. 2, **Isla 3: Meseta Tormenta**, **Elemento Eléctrico** |
| **B5** | `21 – 25` | **Eléctrico (5)** | `14 – 17` | **Isla 3: Meseta Tormenta** | **2.º Catalizador Adulto**, habilitación cruce Opuesto `Tierra+Eléctrico`, **Elemento Hielo** |
| **B6** | `26 – 30` | **Hielo (6)** | `17 – 20` | Isla 3: Meseta Tormenta | **3.er Catalizador Adulto**, Expediciones de Catalizadores, **Isla 4: Ciudadela Forja**, **Elemento Metal** |
| **B7** | `31 – 35` | **Metal (7)** | `20 – 23` | **Isla 4: Ciudadela Forja** | **4.º Catalizador Adulto**, habilitación cruce Opuesto `Agua+Metal`, **Elemento Oscuro** |
| **B8** | `36 – 40` | **Oscuro (8)** | `23 – 26` | Isla 4: Ciudadela Forja | **5.º Catalizador Adulto**, **Isla 5: Santuario Astral**, **Elemento Legendario** |
| **B9** | `41 – 45` | **Legendarios I** | `26 – 28` | **Isla 5: Santuario Astral** | **6.º Catalizador Adulto**, Hábitat Legendario, recetas `Éter` y `Prisma` (4%) |
| **B10** | `46 – 50` | **Legendarios II** | `28 – 30` | Isla 5: Santuario Astral | Recetas `Cronos` y `Astral` (4%), **Ligas Superiores** + **Altar Cromático (Endgame)** |

---

### 3.2 Detalle Económico y Recompensas Capítulo por Capítulo (por Bloques)

#### Bloque 1: Senda de la Tierra (Capítulos 1 – 5)
* **Objetivo de diseño:** Enseñar combate 3v3, ventaja elemental básica (Agua/Planta > Tierra) y eclosión inicial. El jugador inicia con `Dragón Terracota` (Nv. 1) y acceso a la **Isla 1 (Pradera Terracota)**.
* **Caps 1–4 (Normales):** Enemigos Puros de Tierra (Nv. 1–4). Recompensa por capítulo: `150 – 300 Oro`, `50 – 120 Comida`.
* **Cap 5 (Jefe — Guardián Terracota Nv. 5):**
  * **Recompensa:** `600 Oro`, `300 Comida`, **1× Catalizador Joven** (evoluciona a tu primer dragón al llegar a Nv. 10).
  * **Desbloqueo:** **Elemento Fuego (2)** en Tienda (Huevo `Dragón Ascua`, Hábitat Fuego y primeros cruces Tierra+Fuego: `Magma`/`Obsidiana`).

#### Bloque 2: Llama de la Forja (Capítulos 6 – 10)
* **Objetivo de diseño:** Introducir ataques de Fuego y sinergias de 2 elementos (`Magma`, `Obsidiana`).
* **Caps 6–9 (Normales):** Enemigos Fuego y Tierra/Fuego (Nv. 5–7). Recompensa: `350 – 550 Oro`, `150 – 250 Comida`.
* **Cap 10 (Jefe — Señor Ascua Nv. 8):**
  * **Recompensa:** `1,200 Oro`, `600 Comida`, **1× Catalizador Joven**.
  * **Desbloqueo:** **Isla 2: Archipiélago Marea** (pasa de vista previa oscura/bloqueada a comprable/activa) + **Elemento Agua (3)** (`Dragón Marea`, Hábitat Agua).

#### Bloque 3: Corrientes del Archipiélago (Capítulos 11 – 15)
* **Objetivo de diseño:** Consolidar un equipo de 3 dragones en etapa **Joven (Nv. 11+)** aprovechando la ventaja de Agua sobre Tierra y Fuego.
* **Caps 11–14 (Normales):** Enemigos Agua y Agua/Tierra/Fuego (Nv. 8–10). Recompensa: `650 – 900 Oro`, `300 – 450 Comida`.
* **Cap 15 (Jefe — Leviatán Marea Nv. 11, etapa Joven):**
  * **Recompensa:** `2,000 Oro`, `1,000 Comida`, **1× Catalizador Joven**.
  * **Desbloqueo:** **Elemento Planta (4)** (`Dragón Brote`, Hábitat Planta) + **Compra directa de Catalizadores Joven por Oro** en la Tienda (para subir dragones secundarios).

#### Bloque 4: Despertar del Bosque (Capítulos 16 – 20)
* **Objetivo de diseño:** Primer gran punto de inflexión (mitad de los 40 capítulos base). Prepara la transición de Joven a **Adulto (Nv. 21+)**.
* **Caps 16–19 (Normales):** Enemigos Planta y combinados Tierra/Fuego/Agua/Planta (Nv. 11–13). Recompensa: `1,000 – 1,400 Oro`, `500 – 750 Comida`.
* **Cap 20 (Jefe — Ancestro Brote Nv. 14):**
  * **Recompensa:** `3,500 Oro`, `1,800 Comida`, **1× Catalizador Adulto** (primer acceso a etapa Adulto al alcanzar Nv. 20) + **1× Catalizador Joven**.
  * **Desbloqueo:** **Isla 3: Meseta Tormenta** + **Elemento Eléctrico (5)** (`Dragón Chispa`, Hábitat Eléctrico) + **Mejora de Granja Nv. 2** (mayor producción de Comida).

#### Bloque 5: Tormenta Eléctrica (Capítulos 21 – 25)
* **Objetivo de diseño:** Introducir dragones veloces (`Eléctrico`) y el primer cruce de **Híbridos Opuestos** (`Tierra <-> Eléctrico`: `Dragón Sísmico` / `Dragón Telúrico`).
* **Caps 21–24 (Normales):** Enemigos Eléctrico y mixtos (Nv. 14–16). Recompensa: `1,600 – 2,200 Oro`, `850 – 1,200 Comida`.
* **Cap 25 (Jefe — Avatar Chispa Nv. 17):**
  * **Recompensa:** `5,000 Oro`, `2,500 Comida`, **1× Catalizador Adulto**.
  * **Desbloqueo:** **Elemento Hielo (6)** (`Dragón Escarcha`, Hábitat Hielo) + **Manual de Cruces Opuestos I** (desbloquea en Bestiario/Cruce las pistas para `Tierra+Eléctrico` y `Fuego+Hielo`).

#### Bloque 6: Cumbre Glacial (Capítulos 26 – 30)
* **Objetivo de diseño:** Consolidar al menos 2 dragones en etapa **Adulto** y habilitar la obtención repetible de Catalizadores Adulto sin depender solo de jefes.
* **Caps 26–29 (Normales):** Enemigos Hielo y Híbridos de Fuego/Hielo (Nv. 17–19). Recompensa: `2,500 – 3,200 Oro`, `1,300 – 1,800 Comida`.
* **Cap 30 (Jefe — Emperador Escarcha Nv. 20):**
  * **Recompensa:** `7,500 Oro`, `3,800 Comida`, **1× Catalizador Adulto**.
  * **Desbloqueo:** **Isla 4: Ciudadela Forja** + **Elemento Metal (7)** (`Dragón Ferrum`, Hábitat Metal) + **Sistema de Expediciones** (permite enviar dragones inactivos a buscar Oro, Comida y fragmentos de Catalizador Adulto).

#### Bloque 7: Bastión de Metal (Capítulos 31 – 35)
* **Objetivo de diseño:** Combates tácticos contra enemigos de alto HP (`Metal`, `420–445` base), premiando el uso de `Eléctrico` (`×2.0`).
* **Caps 31–34 (Normales):** Enemigos Metal e híbridos Agua/Metal (`Mercurio`, `Hidrometal`) (Nv. 20–22). Recompensa: `3,500 – 4,500 Oro`, `2,000 – 2,600 Comida`.
* **Cap 35 (Jefe — Coloso Ferrum Nv. 23, etapa Adulto):**
  * **Recompensa:** `10,000 Oro`, `5,200 Comida`, **1× Catalizador Adulto**.
  * **Desbloqueo:** **Elemento Oscuro (8)** (`Dragón Umbra`, Hábitat Oscuro) + **Manual de Cruces Opuestos II** (pistas para `Agua+Metal` y `Planta+Oscuro`).

#### Bloque 8: Eclipse Oscuro (Capítulos 36 – 40)
* **Objetivo de diseño:** Cierre de los 8 elementos base. Exige un equipo de **3 Adultos** con cobertura elemental variada para superar Oscuro (`Umbra`, `Espina Negra`, `Abismo`).
* **Caps 36–39 (Normales):** Enemigos Oscuro y Opuestos (Nv. 23–25). Recompensa: `4,800 – 6,000 Oro`, `2,800 – 3,600 Comida`.
* **Cap 40 (Jefe — Soberano Umbra Nv. 26):**
  * **Recompensa:** `15,000 Oro`, `8,000 Comida`, **2× Catalizadores Adulto**.
  * **Desbloqueo:** **Isla 5: Santuario Astral** + **Elemento Legendario (9)** + **Hábitat Legendario** + **Santuario de Cruce Avanzado** (habilita las recetas cerradas del 4%).

#### Bloque 9: Senda del Panteón — Legendarios I (Capítulos 41 – 45)
* **Objetivo de diseño:** Prueba de fuego contra los 4 pares de Híbridos Opuestos. El jugador ya puede intentar los primeros cruces Legendarios (`Éter` y `Prisma`).
* **Caps 41–44 (Normales):** Tríos de Híbridos Opuestos Nv. 26–27 (`Sísmico`, `Telúrico`, `Piroescarcha`, `Termozero`, `Mercurio`, `Hidrometal`, `Marchito`, `Espina Negra`). Recompensa: `6,500 – 8,000 Oro`, `4,000 – 5,000 Comida`.
* **Cap 45 (Jefe — Custodios Éter y Prisma Nv. 28):**
  * **Recompensa:** `22,000 Oro`, `12,000 Comida`, **2× Catalizadores Adulto**, **1× Amuleto de Resonancia** *(mejora temporal o bonificación de suerte en cruce / eclosión)*.
  * **Desbloqueo:** Recetas cerradas de **Dragón Éter (65)** y **Dragón Prisma (66)** visibles en el Bestiario.

#### Bloque 10: Ascensión Primordial — Legendarios II (Capítulos 46 – 50)
* **Objetivo de diseño:** Clímax de la campaña PvE y puente directo hacia las **Ligas Superiores**.
* **Caps 46–49 (Normales / Subjefes):** Equipos mixtos de Opuestos + 1 Legendario enemigo (Nv. 28–29). Recompensa: `9,000 – 12,000 Oro`, `5,500 – 7,500 Comida`.
* **Cap 50 (Gran Jefe Final — Trío Primordial: Cronos, Astral y Dragón Primordial Nv. 30):**
  * **Recompensa:** `40,000 Oro`, `20,000 Comida`, **3× Catalizadores Adulto**, **Trofeo Fundador (Decoración de Isla)** y **1× Esencia Cromática**.
  * **Desbloqueo Mayor:**
    1. **Recetas de `Dragón Cronos (67)` y `Dragón Astral (68)`** completas en el Bestiario.
    2. **Ligas Superiores** (modo competitivo/escalera 3v3 post-campaña).
    3. **Endgame completo:** Altar Cromático y Desafíos con Restricciones.

---

## 4. Ligas Superiores y Sistemas de Endgame

Al completar el **Capítulo 50**, el foco pasa de desbloquear elementos a **completar y optimizar las 68 especies**:

1. **Ligas Superiores (5 Divisiones):**
   * **Divisiones:** Bronce → Plata → Oro → Platino → Leyenda.
   * **Formato:** Series de 3 combates 3v3 contra equipos curados (Opuestos + Legendarios Nv. 25–30) con modificadores semanales de terreno (ej. *Semana Ígnea: +15% ATK Fuego*).
   * **Recompensas:** Oro abundante, Comida, Catalizadores Adulto y **Fragmentos Cromáticos**.
2. **Variantes Cromáticas (Altar Cromático):**
   * Permite desbloquear paletas alternativas y aura sutil en sprites 2D de dragones Adultos Nv. 30 mediante Fragmentos Cromáticos (coleccionismo puro sin *pay-to-win*).
3. **Desafíos con Restricciones (Torre de Maestría):**
   * Retos rotativos que exigen usar toda la colección (ej. *"Solo Dragones Puros"*, *"Solo Híbridos de Agua"*, *"Sin Legendarios"*), dando valor real a las 68 especies.
4. **Expediciones y Reliquias:**
   * Dragones asignados en islas envían recursos pasivos y reliquias cosméticas para personalizar las 5 islas flotantes.

---

## 5. Contrato de Datos Sugerido (para G2, A1 y A2)

Para que **G2** formalice el archivo `data/campana_50.json` y **A1/A2** lo consuman sin ambigüedades:
- Cada capítulo (`id: 1..50`) debe incluir:
  - `bloque_id` (`1..10`), `elemento_foco_id` (`1..9`), `es_jefe` (`bool`)
  - `enemigos`: lista de 3 objetos `{ "especie_id": int, "nivel": int, "etapa": "cria"|"joven"|"adulto" }`
  - `recompensas`: `{ "oro": int, "comida": int, "catalizador_joven": int, "catalizador_adulto": int }`
  - `desbloqueos`: `{ "elemento_id": int|null, "isla_id": int|null, "sistema": string|null }`
- **A1** vincula `isla_id` (`1..5`) con el estado visual de las islas flotantes (bloqueada oscura con preview al clicar vs. desbloqueada) y el inventario de catalizadores en `user://savegame.json`.
- **A2** valida el techo de nivel (`10` sin catalizador, `20` con Catalizador Joven, `30` con Catalizador Adulto) y ejecuta la progresión del Cap 1 al 50 hasta habilitar Ligas Superiores.
