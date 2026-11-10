# Documentação do Banco, Regra de Nulos, Dicionário de Métricas e Validação SQL
**Responsável**: Paul (Dados)  
**Projeto**: Análise de Avaliações de Restaurantes e Consumidores no Metabase (`PostgreSQL Uploads`)

---

## 1. Resumo das Entregas Concluídas (Checklist Paul — Dados)

- [x] **Tratar nulos (`Occupation`, `Budget`, `Children`) e documentar a regra**: Tratados via `COALESCE(NULLIF(TRIM(coluna), ''), 'Não Informado')` em todas as views analíticas.
- [x] **Criar a view `vw_ratings_enriched` (junta as 5 tabelas)**: Criada no schema `public` com **1.161 linhas** (1 linha por avaliação, sem duplicação).
- [x] **Criar views auxiliares sob demanda**:
  - `vw_restaurant_summary` (**130 restaurantes** com médias e total de avaliações pré-calculados);
  - `vw_consumers_clean` (**138 consumidores** únicos com nulos tratados);
  - `vw_cuisine_supply_demand` (**101 culinárias** comparando demanda de consumidores vs. oferta de restaurantes).
- [x] **Sincronizar o schema no Metabase (`Admin → Databases → Sync`) depois de cada view nova**: Schema e valores de filtro (`Re-scan field values`) sincronizados no banco `PostgreSQL Uploads`.
- [x] **Cadastrar as colunas no Metabase com o tipo semântico correto (`Latitude`, `Longitude`, `City`, `State`, `Category`)**: Metadados configurados em `Admin → Table Metadata` nas 4 views.
- [x] **Escrever o dicionário de métricas (versão curta)**: Documentado na Seção 4 deste arquivo.
- [x] **Validar os números dos dashboards contra o SQL**: Números auditados e consolidados na Seção 5 deste arquivo.
- [x] **Documentar o banco e as métricas**: Estrutura física, views e scripts SQL documentados abaixo e no arquivo `views_metabase_paulo.sql`.

---

## 2. Regra de Tratamento de Valores Nulos (`Occupation`, `Budget`, `Children`)

### 2.1 Diagnóstico Inicial na Tabela `consumers` (Total: 138 consumidores)
| Coluna | Qtd. Nulos / Vazios | % da Base | Valores Preenchidos Encontrados |
| :--- | :---: | :---: | :--- |
| **`occupation`** | **7** | `5,07%` | `Student` (113), `Employed` (16), `Unemployed` (2) |
| **`budget`** | **7** | `5,07%` | `Medium` (91), `Low` (35), `High` (5) |
| **`children`** | **11** | `7,97%` | `Independent` (113), `Kids` (11), `Dependent` (3) |

### 2.2 Regra de Negócio Aplicada
```sql
COALESCE(NULLIF(TRIM(coluna), ''), 'Não Informado')
```
* **Justificativa Técnica**:
  1. Como a ingestão via CSV no Metabase grava campos ausentes ora como `NULL`, ora como string vazia (`''`), a função `NULLIF(TRIM(coluna), '')` converte strings vazias ou com espaços para `NULL` antes do `COALESCE`.
  2. O preenchimento explícito com **`'Não Informado'`** (e **`'Não Informada'`** para `cuisine` / `preferred_cuisine`) preserva **100% das 1.161 avaliações** e dos **138 consumidores** nos `JOINs` e nos filtros globais dos dashboards, evitando categorias em branco nos gráficos e sem inflar artificialmente a moda (`Student`, `Medium`, `Independent`).

---

## 3. Arquitetura do Banco de Dados e Views Analíticas

### 3.1 Tabelas Base no PostgreSQL (`schema: public`)
| Tabela Física | Entidade Lógica | Linhas | Chave Primária Lógica | Relacionamento Principal |
| :--- | :--- | :---: | :--- | :--- |
| `ratings_20261027024454` | Avaliações (`ratings`) | 1.161 | `(consumer_id, restaurant_id)` | Tabela Fato (`consumer_id`, `restaurant_id`) |
| `restaurants_20261027024400` | Restaurantes (`restaurants`) | 130 | `restaurant_id` | 1:N com `ratings` e `restaurant_cuisines` |
| `consumers_20261027024431` | Consumidores (`consumers`) | 138 | `consumer_id` | 1:N com `ratings` e `consumer_preferences` |
| `restaurant_cuisines_20261027024421` | Culinárias do Restaurante | 112 | `(restaurant_id, cuisine)` | N:1 com `restaurants` |
| `consumer_preferences_20261027024447` | Preferências do Consumidor | 330 | `(consumer_id, preferred_cuisine)` | N:1 com `consumers` |

### 3.2 Views Analíticas Disponibilizadas no Metabase
1. **`public.vw_ratings_enriched` (1.161 linhas — 1 linha por avaliação)**
   * **Descrição**: View principal que une as 5 tabelas. Pré-agrega as culinárias do restaurante (`rest_cuisines`) e as preferências do consumidor (`cons_prefs`) por chave única antes do `LEFT JOIN`, garantindo que **cada avaliação apareça exatamente 1 vez** sem distorcer médias ou contagens.
   * **Uso**: Dashboards do Tetsuya (KPIs gerais, distribuição de notas, preço × nota, culinária × nota, comida × serviço, franquia × nota) e filtros globais.
2. **`public.vw_restaurant_summary` (130 linhas — 1 linha por restaurante)**
   * **Descrição**: View auxiliar contendo os dados cadastrais/geográficos de cada restaurante, número total de avaliações recebidas (`total_ratings`) e médias pré-calculadas (`avg_overall_rating`, `avg_food_rating`, `avg_service_rating`).
   * **Uso**: Ranking de restaurantes com filtro de mínimo de avaliações e Mapa de Pinos (`Latitude` / `Longitude`).
3. **`public.vw_consumers_clean` (138 linhas — 1 linha por consumidor)**
   * **Descrição**: View demográfica com 1 registro único por consumidor e nulos padronizados.
   * **Uso**: Dashboard Consumidores/Geo do Shida (perfil de idade, ocupação, orçamento, transporte e comparação entre cidades).
4. **`public.vw_cuisine_supply_demand` (101 linhas — 1 linha por culinária)**
   * **Descrição**: `FULL OUTER JOIN` entre a contagem distinta de consumidores que preferem cada culinária (`demanda_consumidores`) e a contagem distinta de restaurantes que a servem (`oferta_restaurantes`).
   * **Uso**: Dashboard Insights do Shida (`Oferta × Demanda de Culinária`).

### 3.3 Tipos Semânticos Cadastrados no Metabase (`Admin → Table Metadata`)
* **`Latitude`**: `restaurant_latitude`, `consumer_latitude`, `latitude`
* **`Longitude`**: `restaurant_longitude`, `consumer_longitude`, `longitude`
* **`City`**: `restaurant_city`, `consumer_city`, `city`
* **`State`**: `restaurant_state`, `consumer_state`, `state`
* **`Country`**: `restaurant_country`, `country`
* **`Category`**: `cuisine`, `preferred_cuisine`, `restaurant_price`, `price`, `occupation`, `budget`, `children`, `marital_status`, `transportation_method`, `drink_level`, `alcohol_service`, `smoking_allowed`, `area`, `parking`

---

## 4. Dicionário de Métricas (Versão Curta)

| Métrica | Fórmula / Regra SQL | Escala / Unidade | View de Referência | Valor Global Validado |
| :--- | :--- | :--- | :--- | :--- |
| **Total de Avaliações** | `COUNT(rating_id)` | Contagem inteira | `vw_ratings_enriched` | **1.161** |
| **Total de Restaurantes** | `COUNT(DISTINCT restaurant_id)` | Contagem inteira | `vw_restaurant_summary` | **130** |
| **Total de Consumidores** | `COUNT(DISTINCT consumer_id)` | Contagem inteira | `vw_consumers_clean` | **138** |
| **Nota Média Geral (`Overall`)** | `ROUND(AVG(overall_rating), 2)` | Escala de `0` a `2` | `vw_ratings_enriched` | **1,20** |
| **Nota Média — Comida (`Food`)** | `ROUND(AVG(food_rating), 2)` | Escala de `0` a `2` | `vw_ratings_enriched` | **1,22** |
| **Nota Média — Serviço (`Service`)** | `ROUND(AVG(service_rating), 2)` | Escala de `0` a `2` | `vw_ratings_enriched` | **1,09** |
| **Nº de Avaliações por Restaurante** | `COUNT(consumer_id) GROUP BY restaurant_id` | Contagem por restaurante | `vw_restaurant_summary` | Mín: `3` · Máx: `36` |
| **Demanda por Culinária** | `COUNT(DISTINCT consumer_id)` por `preferred_cuisine` | Consumidores únicos | `vw_cuisine_supply_demand` | Top 1: `Mexican` (97) |
| **Oferta por Culinária** | `COUNT(DISTINCT restaurant_id)` por `cuisine` | Restaurantes únicos | `vw_cuisine_supply_demand` | Top 1: `Mexican` (28) |

> **Nota sobre a Escala de Avaliação (`0` a `2`)**:  
> Todas as três notas (`overall_rating`, `food_rating`, `service_rating`) utilizam escala inteira de 3 níveis: **`0` = Insatisfatório**, **`1` = Regular/Bom** e **`2` = Excelente**.

---

## 5. Validação Oficial dos Números dos Dashboards contra o SQL

### 5.1 Dashboard Visão Geral & Restaurantes (Tetsuya)

#### KPIs Globais (`vw_ratings_enriched`)
* **Total de Avaliações**: `1.161`
* **Média Geral (`overall_rating`)**: `1,20`
* **Média Comida (`food_rating`)**: `1,22`
* **Média Serviço (`service_rating`)**: `1,09`

#### Distribuição das Notas Gerais (`overall_rating`)
| Nota | Significado | Qtd. Avaliações | % do Total |
| :---: | :--- | :---: | :---: |
| **`2`** | Excelente | **486** | `41,86%` |
| **`1`** | Regular / Bom | **421** | `36,26%` |
| **`0`** | Insatisfatório | **254** | `21,88%` |
| **Total** | — | **1.161** | `100,00%` |

#### Preço do Restaurante × Nota Geral (`restaurant_price`)
| Faixa de Preço | Qtd. Avaliações | Nota Média Geral (`overall_rating`) |
| :--- | :---: | :---: |
| **`High`** | 234 | **1,26** |
| **`Medium`** | 577 | **1,25** |
| **`Low`** | 350 | **1,07** |

#### Franquia × Nota Geral (`is_franchise`)
| É Franquia? | Qtd. Avaliações | Nota Média Geral (`overall_rating`) |
| :--- | :---: | :---: |
| **`true` (Franquia)** | 157 | **1,22** |
| **`false` (Independente)** | 1.004 | **1,20** |

---

### 5.2 Dashboard Consumidores & Geografia (Shida)

#### Ocupação dos Consumidores (`vw_consumers_clean` — Total: 138)
| Ocupação (`occupation`) | Qtd. Consumidores | % do Total | Observação Metodológica |
| :--- | :---: | :---: | :--- |
| **`Student`** | **113** | **`81,88%`** | Confirma o aviso de viés da amostra (**~82% estudantes**) |
| **`Employed`** | **16** | `11,59%` | — |
| **`Não Informado`** | **7** | `5,07%` | Tratado via `COALESCE` |
| **`Unemployed`** | **2** | `1,45%` | — |

#### Orçamento dos Consumidores (`budget` — Total: 138)
| Orçamento (`budget`) | Qtd. Consumidores | % do Total |
| :--- | :---: | :---: |
| **`Medium`** | **91** | `65,94%` |
| **`Low`** | **35** | `25,36%` |
| **`Não Informado`** | **7** | `5,07%` |
| **`High`** | **5** | `3,62%` |

#### Distribuição Geográfica por Cidade (`city` — Total: 138 consumidores)
| Cidade | Qtd. Consumidores | % do Total |
| :--- | :---: | :---: |
| **`San Luis Potosi`** | **86** | `62,32%` |
| **`Ciudad Victoria`** | **25** | `18,12%` |
| **`Cuernavaca`** | **22** | `15,94%` |
| **`Jiutepec`** | **5** | `3,62%` |
