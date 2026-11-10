-- =============================================================================
-- PROJETO METABASE: RESTAURANTES & CONSUMIDORES
-- Responsável: Paul (Dados)
-- Descrição: Scripts de criação das 4 Views Analíticas, Tratamento de Nulos
--            e Consultas de Validação dos Dashboards.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. VIEW PRINCIPAL: vw_ratings_enriched (1.161 linhas - Junta as 5 tabelas)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.vw_ratings_enriched AS
WITH rest_cuisines AS (
    SELECT 
        restaurant_id,
        MIN(cuisine) AS restaurant_cuisine,
        STRING_AGG(DISTINCT cuisine, ', ' ORDER BY cuisine) AS all_restaurant_cuisines
    FROM public.restaurant_cuisines_20261027024421
    GROUP BY restaurant_id
),
cons_prefs AS (
    SELECT 
        consumer_id,
        MIN(preferred_cuisine) AS preferred_cuisine,
        STRING_AGG(DISTINCT preferred_cuisine, ', ' ORDER BY preferred_cuisine) AS all_preferred_cuisines
    FROM public.consumer_preferences_20261027024447
    GROUP BY consumer_id
)
SELECT
    -- 1. Avaliação (ratings)
    rt._mb_row_id AS rating_id,
    rt.consumer_id,
    rt.restaurant_id,
    rt.overall_rating,
    rt.food_rating,
    rt.service_rating,

    -- 2. Restaurante (restaurants)
    r.name AS restaurant_name,
    r.city AS restaurant_city,
    r.state AS restaurant_state,
    r.country AS restaurant_country,
    r.latitude AS restaurant_latitude,
    r.longitude AS restaurant_longitude,
    r.price AS restaurant_price,
    r.franchise AS is_franchise,
    r.alcohol_service,
    r.smoking_allowed,
    r.area AS restaurant_area,
    r.parking AS restaurant_parking,

    -- 3. Culinária do Restaurante (restaurant_cuisines)
    COALESCE(NULLIF(TRIM(rc.restaurant_cuisine), ''), 'Não Informada') AS cuisine,
    COALESCE(NULLIF(TRIM(rc.all_restaurant_cuisines), ''), 'Não Informada') AS all_restaurant_cuisines,

    -- 4. Consumidor com Nulos Tratados (consumers)
    c.city AS consumer_city,
    c.state AS consumer_state,
    c.latitude AS consumer_latitude,
    c.longitude AS consumer_longitude,
    c.age AS consumer_age,
    COALESCE(NULLIF(TRIM(c.occupation), ''), 'Não Informado') AS occupation,
    COALESCE(NULLIF(TRIM(c.budget), ''), 'Não Informado') AS budget,
    COALESCE(NULLIF(TRIM(c.children), ''), 'Não Informado') AS children,
    COALESCE(NULLIF(TRIM(c.marital_status), ''), 'Não Informado') AS marital_status,
    COALESCE(NULLIF(TRIM(c.transportation_method), ''), 'Não Informado') AS transportation_method,
    COALESCE(NULLIF(TRIM(c.drink_level), ''), 'Não Informado') AS drink_level,
    c.smoker AS consumer_smoker,

    -- 5. Preferência do Consumidor (consumer_preferences)
    COALESCE(NULLIF(TRIM(cp.preferred_cuisine), ''), 'Não Informada') AS preferred_cuisine,
    COALESCE(NULLIF(TRIM(cp.all_preferred_cuisines), ''), 'Não Informada') AS all_preferred_cuisines

FROM public.ratings_20261027024454 rt
LEFT JOIN public.restaurants_20261027024400 r
    ON rt.restaurant_id = r.restaurant_id
LEFT JOIN rest_cuisines rc
    ON rt.restaurant_id = rc.restaurant_id
LEFT JOIN public.consumers_20261027024431 c
    ON rt.consumer_id = c.consumer_id
LEFT JOIN cons_prefs cp
    ON rt.consumer_id = cp.consumer_id;


-- -----------------------------------------------------------------------------
-- 2. VIEW AUXILIAR 1: vw_restaurant_summary (130 linhas - Média e nº avaliações)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.vw_restaurant_summary AS
WITH rest_cuisines AS (
    SELECT 
        restaurant_id,
        MIN(cuisine) AS cuisine,
        STRING_AGG(DISTINCT cuisine, ', ' ORDER BY cuisine) AS all_cuisines
    FROM public.restaurant_cuisines_20261027024421
    GROUP BY restaurant_id
)
SELECT
    r.restaurant_id,
    r.name AS restaurant_name,
    r.city,
    r.state,
    r.country,
    r.latitude,
    r.longitude,
    r.price,
    r.franchise,
    r.alcohol_service,
    r.smoking_allowed,
    r.area,
    r.parking,
    COALESCE(NULLIF(TRIM(rc.cuisine), ''), 'Não Informada') AS cuisine,
    COALESCE(NULLIF(TRIM(rc.all_cuisines), ''), 'Não Informada') AS all_cuisines,
    COUNT(rt.consumer_id) AS total_ratings,
    ROUND(AVG(rt.overall_rating)::numeric, 2) AS avg_overall_rating,
    ROUND(AVG(rt.food_rating)::numeric, 2) AS avg_food_rating,
    ROUND(AVG(rt.service_rating)::numeric, 2) AS avg_service_rating
FROM public.restaurants_20261027024400 r
LEFT JOIN public.ratings_20261027024454 rt
    ON r.restaurant_id = rt.restaurant_id
LEFT JOIN rest_cuisines rc
    ON r.restaurant_id = rc.restaurant_id
GROUP BY
    r.restaurant_id, r.name, r.city, r.state, r.country,
    r.latitude, r.longitude, r.price, r.franchise,
    r.alcohol_service, r.smoking_allowed, r.area, r.parking,
    rc.cuisine, rc.all_cuisines;


-- -----------------------------------------------------------------------------
-- 3. VIEW AUXILIAR 2: vw_consumers_clean (138 linhas - Consumidores s/ nulos)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.vw_consumers_clean AS
SELECT
    c.consumer_id,
    c.city,
    c.state,
    c.country,
    c.latitude,
    c.longitude,
    c.age,
    COALESCE(NULLIF(TRIM(c.occupation), ''), 'Não Informado') AS occupation,
    COALESCE(NULLIF(TRIM(c.budget), ''), 'Não Informado') AS budget,
    COALESCE(NULLIF(TRIM(c.children), ''), 'Não Informado') AS children,
    COALESCE(NULLIF(TRIM(c.marital_status), ''), 'Não Informado') AS marital_status,
    COALESCE(NULLIF(TRIM(c.transportation_method), ''), 'Não Informado') AS transportation_method,
    COALESCE(NULLIF(TRIM(c.drink_level), ''), 'Não Informado') AS drink_level,
    c.smoker
FROM public.consumers_20261027024431 c;


-- -----------------------------------------------------------------------------
-- 4. VIEW AUXILIAR 3: vw_cuisine_supply_demand (101 linhas - Oferta x Demanda)
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.vw_cuisine_supply_demand AS
WITH demanda AS (
    SELECT 
        TRIM(preferred_cuisine) AS cuisine,
        COUNT(DISTINCT consumer_id) AS qtd_consumidores_preferem
    FROM public.consumer_preferences_20261027024447
    WHERE preferred_cuisine IS NOT NULL AND TRIM(preferred_cuisine) <> ''
    GROUP BY TRIM(preferred_cuisine)
),
oferta AS (
    SELECT 
        TRIM(cuisine) AS cuisine,
        COUNT(DISTINCT restaurant_id) AS qtd_restaurantes_servem
    FROM public.restaurant_cuisines_20261027024421
    WHERE cuisine IS NOT NULL AND TRIM(cuisine) <> ''
    GROUP BY TRIM(cuisine)
)
SELECT
    COALESCE(d.cuisine, o.cuisine) AS cuisine,
    COALESCE(d.qtd_consumidores_preferem, 0) AS demanda_consumidores,
    COALESCE(o.qtd_restaurantes_servem, 0) AS oferta_restaurantes
FROM demanda d
FULL OUTER JOIN oferta o ON d.cuisine = o.cuisine
ORDER BY demanda_consumidores DESC, oferta_restaurantes DESC;


-- -----------------------------------------------------------------------------
-- 5. CONSULTAS DE VALIDAÇÃO DOS DASHBOARDS CONTRA O SQL
-- -----------------------------------------------------------------------------
-- 5.1 KPIs Globais
SELECT 
    COUNT(*) AS total_avaliacoes, 
    ROUND(AVG(overall_rating), 2) AS media_geral,
    ROUND(AVG(food_rating), 2) AS media_comida,
    ROUND(AVG(service_rating), 2) AS media_servico
FROM public.vw_ratings_enriched;

-- 5.2 Gabarito Consolidado (Cidade, Ocupação, Orçamento, Preço, Franquia, Notas)
SELECT '1. Cidade (Consumidores)' AS dimensao, city AS categoria, COUNT(*) AS qtd, NULL::numeric AS media_geral
FROM public.vw_consumers_clean GROUP BY city
UNION ALL
SELECT '2. Ocupação (Consumidores)', occupation, COUNT(*), NULL
FROM public.vw_consumers_clean GROUP BY occupation
UNION ALL
SELECT '3. Orçamento (Consumidores)', budget, COUNT(*), NULL
FROM public.vw_consumers_clean GROUP BY budget
UNION ALL
SELECT '4. Preço × Nota (Avaliações)', restaurant_price, COUNT(*), ROUND(AVG(overall_rating), 2)
FROM public.vw_ratings_enriched GROUP BY restaurant_price
UNION ALL
SELECT '5. Franquia × Nota (Avaliações)', CAST(is_franchise AS varchar), COUNT(*), ROUND(AVG(overall_rating), 2)
FROM public.vw_ratings_enriched GROUP BY is_franchise
UNION ALL
SELECT '6. Distribuição Notas Gerais', CAST(overall_rating AS varchar), COUNT(*), NULL
FROM public.vw_ratings_enriched GROUP BY overall_rating
ORDER BY dimensao, qtd DESC;
