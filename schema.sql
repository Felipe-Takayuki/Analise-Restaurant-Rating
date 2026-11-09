-- =====================================================================
-- Estrutura da Base de Dados: Restaurant Ratings
-- Compatível com: PostgreSQL, MySQL, SQLite, MariaDB, SQL Server
-- =====================================================================

-- 1. Remoção de tabelas pré-existentes (na ordem inversa de dependência)
DROP TABLE IF EXISTS ratings;
DROP TABLE IF EXISTS restaurant_cuisines;
DROP TABLE IF EXISTS consumer_preferences;
DROP TABLE IF EXISTS restaurants;
DROP TABLE IF EXISTS consumers;

-- 2. Tabela de Consumidores (Consumers)
CREATE TABLE consumers (
    consumer_id             VARCHAR(10)     PRIMARY KEY,
    city                    VARCHAR(50),
    state                   VARCHAR(50),
    country                 VARCHAR(50),
    latitude                DECIMAL(10, 6),
    longitude               DECIMAL(11, 6),
    smoker                  VARCHAR(10),
    drink_level             VARCHAR(30),
    transportation_method   VARCHAR(30),
    marital_status          VARCHAR(20),
    children                VARCHAR(20),
    age                     INT,
    occupation              VARCHAR(30),
    budget                  VARCHAR(20)
);

-- 3. Tabela de Restaurantes (Restaurants)
CREATE TABLE restaurants (
    restaurant_id           INT             PRIMARY KEY,
    name                    VARCHAR(100)    NOT NULL,
    city                    VARCHAR(50),
    state                   VARCHAR(50),
    country                 VARCHAR(50),
    zip_code                VARCHAR(20),
    latitude                DECIMAL(10, 7),
    longitude               DECIMAL(11, 7),
    alcohol_service         VARCHAR(30),
    smoking_allowed         VARCHAR(30),
    price                   VARCHAR(20),
    franchise               VARCHAR(10),
    area                    VARCHAR(20),
    parking                 VARCHAR(30)
);

-- 4. Preferências Culinárias dos Consumidores (Consumer Preferences)
-- Obs: A base original possui 2 registros duplicados no CSV (U1135: Pacific e Asian),
-- por isso recomenda-se importar com DISTINCT ou INSERT IGNORE / ON CONFLICT DO NOTHING.
CREATE TABLE consumer_preferences (
    consumer_id             VARCHAR(10)     NOT NULL,
    preferred_cuisine       VARCHAR(50)     NOT NULL,
    PRIMARY KEY (consumer_id, preferred_cuisine),
    CONSTRAINT fk_consumer_preferences_consumer 
        FOREIGN KEY (consumer_id) REFERENCES consumers(consumer_id) 
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 5. Tipos de Culinária dos Restaurantes (Restaurant Cuisines)
CREATE TABLE restaurant_cuisines (
    restaurant_id           INT             NOT NULL,
    cuisine                 VARCHAR(50)     NOT NULL,
    PRIMARY KEY (restaurant_id, cuisine),
    CONSTRAINT fk_restaurant_cuisines_restaurant 
        FOREIGN KEY (restaurant_id) REFERENCES restaurants(restaurant_id) 
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- 6. Avaliações (Ratings)
-- Notas variam de 0 (Insatisfatório), 1 (Satisfatório) a 2 (Muito Satisfatório)
CREATE TABLE ratings (
    consumer_id             VARCHAR(10)     NOT NULL,
    restaurant_id           INT             NOT NULL,
    overall_rating          INT             CHECK (overall_rating BETWEEN 0 AND 2),
    food_rating             INT             CHECK (food_rating BETWEEN 0 AND 2),
    service_rating          INT             CHECK (service_rating BETWEEN 0 AND 2),
    PRIMARY KEY (consumer_id, restaurant_id),
    CONSTRAINT fk_ratings_consumer 
        FOREIGN KEY (consumer_id) REFERENCES consumers(consumer_id) 
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ratings_restaurant 
        FOREIGN KEY (restaurant_id) REFERENCES restaurants(restaurant_id) 
        ON DELETE CASCADE ON UPDATE CASCADE
);
