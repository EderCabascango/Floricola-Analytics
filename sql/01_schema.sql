-- 01_schema.sql
-- Esquema inicial de la florícola (versión mini, se ampliará en el Día 3)

DROP TABLE IF EXISTS venta, cosecha, cliente, variedad CASCADE;

CREATE TABLE variedad (
    variedad_id  SERIAL PRIMARY KEY,
    nombre       TEXT NOT NULL UNIQUE,
    tipo         TEXT NOT NULL              -- 'Rosa', 'Gypsophila', 'Clavel'
);

CREATE TABLE cliente (
    cliente_id   SERIAL PRIMARY KEY,
    nombre       TEXT NOT NULL,
    pais_destino TEXT NOT NULL,
    tipo         TEXT NOT NULL              -- 'Importador', 'Broker', 'Retailer'
);

CREATE TABLE cosecha (
    cosecha_id   SERIAL PRIMARY KEY,
    fecha        DATE NOT NULL,
    bloque       TEXT NOT NULL,             -- 'B01', 'B02'...
    variedad_id  INTEGER NOT NULL REFERENCES variedad(variedad_id),
    tallos       INTEGER NOT NULL CHECK (tallos >= 0)
);

CREATE TABLE venta (
    venta_id     SERIAL PRIMARY KEY,
    fecha        DATE NOT NULL,
    cliente_id   INTEGER NOT NULL REFERENCES cliente(cliente_id),
    variedad_id  INTEGER NOT NULL REFERENCES variedad(variedad_id),
    empaque      TEXT NOT NULL CHECK (empaque IN ('FB','HB','QB','EB')),
    tallos       INTEGER NOT NULL CHECK (tallos > 0),
    precio_tallo NUMERIC(6,3) NOT NULL CHECK (precio_tallo > 0)
);