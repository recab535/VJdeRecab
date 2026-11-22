-- ==========================================
-- 1. POBLADO DE ELEMENTOS Y OPUESTOS
-- ==========================================
INSERT INTO elementos (id, nombre, elemento_opuesto_id) VALUES
(1, 'Tierra', NULL),
(2, 'Fuego', NULL),
(3, 'Agua', NULL),
(4, 'Planta', NULL),
(5, 'Eléctrico', NULL),
(6, 'Hielo', NULL),
(7, 'Metal', NULL),
(8, 'Oscuro', NULL),
(9, 'Legendario', NULL);

UPDATE elementos SET elemento_opuesto_id = 5 WHERE id = 1; -- Tierra <-> Eléctrico
UPDATE elementos SET elemento_opuesto_id = 6 WHERE id = 2; -- Fuego <-> Hielo
UPDATE elementos SET elemento_opuesto_id = 7 WHERE id = 3; -- Agua <-> Metal
UPDATE elementos SET elemento_opuesto_id = 8 WHERE id = 4; -- Planta <-> Oscuro
UPDATE elementos SET elemento_opuesto_id = 1 WHERE id = 5;
UPDATE elementos SET elemento_opuesto_id = 2 WHERE id = 6;
UPDATE elementos SET elemento_opuesto_id = 3 WHERE id = 7;
UPDATE elementos SET elemento_opuesto_id = 4 WHERE id = 8;

-- ==========================================
-- 2. MATRIZ COMPLETA DE MULTIPLICADORES (9x9)
-- ==========================================
INSERT INTO multiplicadores_elementales (elemento_ataque_id, elemento_defensa_id, multiplicador) VALUES
-- Atacante: Tierra (1) -> Crítico a Fuego (2) y Eléctrico (5)
(1,1,0.50),(1,2,2.00),(1,3,1.00),(1,4,1.00),(1,5,2.00),(1,6,1.00),(1,7,1.00),(1,8,1.00),(1,9,1.00),
-- Atacante: Fuego (2) -> Crítico a Planta (4) y Hielo (6)
(2,1,1.00),(2,2,0.50),(2,3,1.00),(2,4,2.00),(2,5,1.00),(2,6,2.00),(2,7,1.00),(2,8,1.00),(2,9,1.00),
-- Atacante: Agua (3) -> Crítico a Tierra (1) y Fuego (2)
(3,1,2.00),(3,2,2.00),(3,3,0.50),(3,4,1.00),(3,5,1.00),(3,6,1.00),(3,7,1.00),(3,8,1.00),(3,9,1.00),
-- Atacante: Planta (4) -> Crítico a Tierra (1) y Agua (3)
(4,1,2.00),(4,2,1.00),(4,3,2.00),(4,4,0.50),(4,5,1.00),(4,6,1.00),(4,7,1.00),(4,8,1.00),(4,9,1.00),
-- Atacante: Eléctrico (5) -> Crítico a Agua (3) y Metal (7)
(5,1,1.00),(5,2,1.00),(5,3,2.00),(5,4,1.00),(5,5,0.50),(5,6,1.00),(5,7,2.00),(5,8,1.00),(5,9,1.00),
-- Atacante: Hielo (6) -> Crítico a Planta (4) y Eléctrico (5)
(6,1,1.00),(6,2,1.00),(6,3,1.00),(6,4,2.00),(6,5,2.00),(6,6,0.50),(6,7,1.00),(6,8,1.00),(6,9,1.00),
-- Atacante: Metal (7) -> Crítico a Hielo (6) y Oscuro (8)
(7,1,1.00),(7,2,1.00),(7,3,1.00),(7,4,1.00),(7,5,1.00),(7,6,2.00),(7,7,0.50),(7,8,2.00),(7,9,1.00),
-- Atacante: Oscuro (8) -> Crítico a Tierra (1) y Metal (7)
(8,1,2.00),(8,2,1.00),(8,3,1.00),(8,4,1.00),(8,5,1.00),(8,6,1.00),(8,7,2.00),(8,8,0.50),(8,9,1.00),
-- Atacante: Legendario (9) -> Crítico solo a Legendario (9)
(9,1,1.00),(9,2,1.00),(9,3,1.00),(9,4,1.00),(9,5,1.00),(9,6,1.00),(9,7,1.00),(9,8,1.00),(9,9,2.00);

-- ==========================================
-- 3. CATÁLOGO BASE DE 68 ESPECIES
-- ==========================================
INSERT INTO especies_dragon (
    id, nombre, rareza, elemento_primario_id, elemento_secundario_id,
    hp_base, atk_base, spd_base, oro_por_minuto,
    tiempo_cria_seg, tiempo_incubacion_seg, sprite_prefijo
) VALUES
-- 8 PUROS (IDs 1 - 8)
(1, 'Dragón Terracota', 'PURO', 1, NULL, 420, 85, 40, 12, 300, 300, 'dragon_terracota'),
(2, 'Dragón Ascua', 'PURO', 2, NULL, 310, 120, 65, 14, 600, 600, 'dragon_ascua'),
(3, 'Dragón Marea', 'PURO', 3, NULL, 365, 100, 55, 15, 1200, 1200, 'dragon_marea'),
(4, 'Dragón Brote', 'PURO', 4, NULL, 365, 100, 55, 16, 1800, 1800, 'dragon_brote'),
(5, 'Dragón Chispa', 'PURO', 5, NULL, 310, 120, 65, 18, 2700, 2700, 'dragon_chispa'),
(6, 'Dragón Escarcha', 'PURO', 6, NULL, 335, 110, 75, 20, 3600, 3600, 'dragon_escarcha'),
(7, 'Dragón Ferrum', 'PURO', 7, NULL, 420, 85, 40, 22, 5400, 5400, 'dragon_ferrum'),
(8, 'Dragón Umbra', 'PURO', 8, NULL, 335, 110, 75, 25, 7200, 7200, 'dragon_umbra'),

-- 48 HÍBRIDOS ESTÁNDAR (24 pares x 2 variantes al 50% / 50%) (IDs 9 - 56)
(9, 'Dragón Magma', 'HIBRIDO', 1, 2, 420, 90, 40, 24, 3600, 3600, 'dragon_magma'),
(10, 'Dragón Obsidiana', 'HIBRIDO', 2, 1, 329, 120, 65, 26, 3600, 3600, 'dragon_obsidiana'),
(11, 'Dragón Lodo', 'HIBRIDO', 1, 3, 433, 88, 40, 25, 4500, 4500, 'dragon_lodo'),
(12, 'Dragón Pantano', 'HIBRIDO', 3, 1, 387, 100, 55, 27, 4500, 4500, 'dragon_pantano'),
(13, 'Dragón Raíz', 'HIBRIDO', 1, 4, 433, 88, 40, 26, 5400, 5400, 'dragon_raiz'),
(14, 'Dragón Musgo', 'HIBRIDO', 4, 1, 387, 100, 55, 28, 5400, 5400, 'dragon_musgo'),
(15, 'Dragón Permafrost', 'HIBRIDO', 1, 6, 420, 85, 42, 30, 7200, 7200, 'dragon_permafrost'),
(16, 'Dragón Glaciar', 'HIBRIDO', 6, 1, 355, 110, 75, 32, 7200, 7200, 'dragon_glaciar'),
(17, 'Dragón Mena', 'HIBRIDO', 1, 7, 445, 85, 40, 32, 9000, 9000, 'dragon_mena'),
(18, 'Dragón Tungsteno', 'HIBRIDO', 7, 1, 445, 85, 40, 34, 9000, 9000, 'dragon_tungsteno'),
(19, 'Dragón Caverna', 'HIBRIDO', 1, 8, 420, 85, 42, 35, 10800, 10800, 'dragon_caverna'),
(20, 'Dragón Abismo', 'HIBRIDO', 8, 1, 355, 110, 75, 36, 10800, 10800, 'dragon_abismo'),
(21, 'Dragón Vapor', 'HIBRIDO', 2, 3, 319, 124, 65, 28, 5400, 5400, 'dragon_vapor'),
(22, 'Dragón Géiser', 'HIBRIDO', 3, 2, 365, 106, 55, 30, 5400, 5400, 'dragon_geiser'),
(23, 'Dragón Ceniza', 'HIBRIDO', 2, 4, 319, 124, 65, 28, 5400, 5400, 'dragon_ceniza'),
(24, 'Dragón Ámbar', 'HIBRIDO', 4, 2, 365, 106, 55, 30, 5400, 5400, 'dragon_ambar'),
(25, 'Dragón Plasma', 'HIBRIDO', 2, 5, 310, 127, 65, 34, 9000, 9000, 'dragon_plasma'),
(26, 'Dragón Relámpago', 'HIBRIDO', 5, 2, 310, 127, 65, 36, 9000, 9000, 'dragon_relampago'),
(27, 'Dragón Forja', 'HIBRIDO', 2, 7, 329, 120, 65, 35, 10800, 10800, 'dragon_forja'),
(28, 'Dragón Crisol', 'HIBRIDO', 7, 2, 420, 90, 40, 37, 10800, 10800, 'dragon_crisol'),
(29, 'Dragón Piroumbra', 'HIBRIDO', 2, 8, 310, 120, 69, 38, 14400, 14400, 'dragon_piroumbra'),
(30, 'Dragón Eclipse', 'HIBRIDO', 8, 2, 335, 117, 75, 40, 14400, 14400, 'dragon_eclipse'),
(31, 'Dragón Coral', 'HIBRIDO', 3, 4, 376, 103, 55, 30, 7200, 7200, 'dragon_coral'),
(32, 'Dragón Nenúfar', 'HIBRIDO', 4, 3, 376, 103, 55, 31, 7200, 7200, 'dragon_nenufar'),
(33, 'Dragón Tormenta', 'HIBRIDO', 3, 5, 365, 106, 55, 34, 9000, 9000, 'dragon_tormenta'),
(34, 'Dragón Anguila', 'HIBRIDO', 5, 3, 319, 124, 65, 36, 9000, 9000, 'dragon_anguila'),
(35, 'Dragón Iceberg', 'HIBRIDO', 3, 6, 365, 100, 58, 35, 10800, 10800, 'dragon_iceberg'),
(36, 'Dragón Ventisca', 'HIBRIDO', 6, 3, 345, 113, 75, 37, 10800, 10800, 'dragon_ventisca'),
(37, 'Dragón Fosa', 'HIBRIDO', 3, 8, 365, 100, 58, 38, 14400, 14400, 'dragon_fosa'),
(38, 'Dragón Leviatán', 'HIBRIDO', 8, 3, 345, 113, 75, 40, 14400, 14400, 'dragon_leviatan'),
(39, 'Dragón Espora', 'HIBRIDO', 4, 5, 365, 106, 55, 34, 9000, 9000, 'dragon_espora'),
(40, 'Dragón Fotón', 'HIBRIDO', 5, 4, 319, 124, 65, 36, 9000, 9000, 'dragon_foton'),
(41, 'Dragón Conífera', 'HIBRIDO', 4, 6, 365, 100, 58, 35, 10800, 10800, 'dragon_conifera'),
(42, 'Dragón Tundra', 'HIBRIDO', 6, 4, 345, 113, 75, 37, 10800, 10800, 'dragon_tundra'),
(43, 'Dragón Titanio', 'HIBRIDO', 4, 7, 387, 100, 55, 38, 14400, 14400, 'dragon_titanio'),
(44, 'Dragón Pátina', 'HIBRIDO', 7, 4, 433, 88, 40, 39, 14400, 14400, 'dragon_patina'),
(45, 'Dragón Aurora', 'HIBRIDO', 5, 6, 310, 120, 69, 40, 14400, 14400, 'dragon_aurora'),
(46, 'Dragón Criovoltio', 'HIBRIDO', 6, 5, 335, 117, 75, 42, 14400, 14400, 'dragon_criovoltio'),
(47, 'Dragón Bobina', 'HIBRIDO', 5, 7, 329, 120, 65, 42, 18000, 18000, 'dragon_bobina'),
(48, 'Dragón Magneto', 'HIBRIDO', 7, 5, 420, 90, 40, 44, 18000, 18000, 'dragon_magneto'),
(49, 'Dragón Némesis', 'HIBRIDO', 5, 8, 310, 120, 69, 45, 21600, 21600, 'dragon_nemesis'),
(50, 'Dragón Espectro', 'HIBRIDO', 8, 5, 335, 117, 75, 46, 21600, 21600, 'dragon_espectro'),
(51, 'Dragón Cromo', 'HIBRIDO', 6, 7, 355, 110, 75, 42, 18000, 18000, 'dragon_cromo'),
(52, 'Dragón Acero Frío', 'HIBRIDO', 7, 6, 420, 85, 42, 44, 18000, 18000, 'dragon_acero_frio'),
(53, 'Dragón Nocturno', 'HIBRIDO', 6, 8, 335, 110, 80, 45, 21600, 21600, 'dragon_nocturno'),
(54, 'Dragón Penumbra', 'HIBRIDO', 8, 6, 335, 110, 80, 46, 21600, 21600, 'dragon_penumbra'),
(55, 'Dragón Onix', 'HIBRIDO', 7, 8, 420, 85, 42, 46, 21600, 21600, 'dragon_onix'),
(56, 'Dragón Vacío Férreo', 'HIBRIDO', 8, 7, 355, 110, 75, 48, 21600, 21600, 'dragon_vacio_ferreo'),

-- 8 HÍBRIDOS OPUESTOS (4 pares antagónicos x 2 variantes) (IDs 57 - 64)
(57, 'Dragón Sísmico', 'OPUESTO', 1, 5, 420, 90, 40, 55, 28800, 28800, 'dragon_sismico'),
(58, 'Dragón Telúrico', 'OPUESTO', 5, 1, 329, 120, 65, 56, 28800, 28800, 'dragon_telurico'),
(59, 'Dragón Piroescarcha', 'OPUESTO', 2, 6, 310, 120, 69, 58, 32400, 32400, 'dragon_piroescarcha'),
(60, 'Dragón Termozero', 'OPUESTO', 6, 2, 335, 117, 75, 60, 32400, 32400, 'dragon_termozero'),
(61, 'Dragón Mercurio', 'OPUESTO', 3, 7, 387, 100, 55, 58, 32400, 32400, 'dragon_mercurio'),
(62, 'Dragón Hidrometal', 'OPUESTO', 7, 3, 433, 88, 40, 60, 32400, 32400, 'dragon_hidrometal'),
(63, 'Dragón Marchito', 'OPUESTO', 4, 8, 365, 100, 58, 60, 36000, 36000, 'dragon_marchito'),
(64, 'Dragón Espina Negra', 'OPUESTO', 8, 4, 345, 113, 75, 62, 36000, 36000, 'dragon_espina_negra'),

-- 4 LEGENDARIOS (IDs 65 - 68)
(65, 'Dragón Éter', 'LEGENDARIO', 9, NULL, 460, 135, 80, 110, 129600, 129600, 'dragon_eter'),
(66, 'Dragón Prisma', 'LEGENDARIO', 9, NULL, 460, 135, 80, 115, 144000, 144000, 'dragon_prisma'),
(67, 'Dragón Cronos', 'LEGENDARIO', 9, NULL, 460, 135, 80, 120, 158400, 158400, 'dragon_cronos'),
(68, 'Dragón Astral', 'LEGENDARIO', 9, NULL, 460, 135, 80, 125, 172800, 172800, 'dragon_astral');

-- ==========================================
-- 4. RECETAS CERRADAS DE LEGENDARIOS (4% PROBABILIDAD)
-- ==========================================
INSERT INTO recetas_legendarias (padre_a_id, padre_b_id, legendario_id, probabilidad) VALUES
(57, 59, 65, 0.040), -- Dragón Sísmico + Dragón Piroescarcha -> Dragón Éter
(61, 63, 66, 0.040), -- Dragón Mercurio + Dragón Marchito -> Dragón Prisma
(58, 62, 67, 0.040), -- Dragón Telúrico + Dragón Hidrometal -> Dragón Cronos
(60, 64, 68, 0.040); -- Dragón Termozero + Dragón Espina Negra -> Dragón Astral

-- Sincronizar secuencia en PostgreSQL
SELECT setval(pg_get_serial_sequence('especies_dragon', 'id'), 68);