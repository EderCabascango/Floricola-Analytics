DROP TABLE IF EXISTS despacho, inventario_movimiento, venta, cosecha,
agencia_carga, aerolinea, cuarto_frio, bloque, cliente, variedad CASCADE;
-- Catalogo de variedades de flores cultivadas y exportadas
CREATE TABLE variedad (
    variedad_id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) UNIQUE NOT NULL,
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('Rosa', 'Gypsophila', 'Clavel')),
    color VARCHAR(50) NOT NULL
);
-- Bloques o lotes de cultivo dentro de la finca floricola
CREATE TABLE bloque (
    bloque_id SERIAL PRIMARY KEY,
    codigo VARCHAR(20) UNIQUE NOT NULL,
    hectareas NUMERIC(6, 2) NOT NULL CHECK (hectareas > 0),
    variedad_id INTEGER NOT NULL REFERENCES variedad(variedad_id)
);
-- Cuartos frios de almacenamiento poscosecha y control de temperatura
CREATE TABLE cuarto_frio (
    cuarto_frio_id SERIAL PRIMARY KEY,
    codigo VARCHAR(20) UNIQUE NOT NULL,
    temperatura_objetivo NUMERIC(4, 2),
    capacidad_cajas INTEGER NOT NULL CHECK (capacidad_cajas > 0)
);
-- Clientes internacionales y compradores mayoristas
CREATE TABLE cliente (
    cliente_id SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    pais_destino VARCHAR(100) NOT NULL,
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('Importador', 'Broker', 'Retailer'))
);
-- Aerolineas de transporte internacional de carga perecible
CREATE TABLE aerolinea (
    aerolinea_id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    codigo_iata CHAR(2) UNIQUE NOT NULL
);
-- Agencias de carga y logistica internacional para exportacion
CREATE TABLE agencia_carga (
    agencia_carga_id SERIAL PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    pais VARCHAR(100) NOT NULL
);
-- Registro diario de tallos cortados por bloque y clasificacion de calidad
CREATE TABLE cosecha (
    cosecha_id SERIAL PRIMARY KEY,
    fecha DATE NOT NULL,
    bloque_id INTEGER NOT NULL REFERENCES bloque(bloque_id),
    tallos INTEGER NOT NULL CHECK (tallos > 0),
    grado_calidad CHAR(1) NOT NULL CHECK (grado_calidad IN ('A', 'B', 'C')),
    largo_cm INTEGER NOT NULL CHECK (largo_cm > 0)
);
-- Movimientos de inventario de flor en cuartos frios (entradas, salidas y mermas)
CREATE TABLE inventario_movimiento (
    movimiento_id SERIAL PRIMARY KEY,
    fecha DATE NOT NULL,
    cuarto_frio_id INTEGER NOT NULL REFERENCES cuarto_frio(cuarto_frio_id),
    cosecha_id INTEGER REFERENCES cosecha(cosecha_id),
    tipo_movimiento VARCHAR(10) NOT NULL CHECK (tipo_movimiento IN ('entrada', 'salida', 'merma')),
    cantidad INTEGER NOT NULL CHECK (cantidad > 0)
);
-- Transacciones comerciales de venta de flor a clientes internacionales
CREATE TABLE venta (
    venta_id SERIAL PRIMARY KEY,
    fecha DATE NOT NULL,
    cliente_id INTEGER NOT NULL REFERENCES cliente(cliente_id),
    variedad_id INTEGER NOT NULL REFERENCES variedad(variedad_id),
    empaque VARCHAR(2) NOT NULL CHECK (empaque IN ('FB', 'HB', 'QB', 'EB')),
    tallos INTEGER NOT NULL CHECK (tallos > 0),
    precio_tallo NUMERIC(6, 3) NOT NULL CHECK (precio_tallo > 0)
);
-- Despachos fisicos y logistica de exportacion asociados a una venta
CREATE TABLE despacho (
    despacho_id SERIAL PRIMARY KEY,
    fecha DATE NOT NULL,
    venta_id INTEGER NOT NULL REFERENCES venta(venta_id),
    aerolinea_id INTEGER NOT NULL REFERENCES aerolinea(aerolinea_id),
    agencia_carga_id INTEGER REFERENCES agencia_carga(agencia_carga_id),
    awb VARCHAR(15) UNIQUE,
    peso_kg NUMERIC(8, 2) NOT NULL CHECK (peso_kg > 0)
);
-- Indices para optimizacion de JOINs en columnas de clave foranea
CREATE INDEX idx_bloque_variedad_id ON bloque(variedad_id);
CREATE INDEX idx_cosecha_bloque_id ON cosecha(bloque_id);
CREATE INDEX idx_inventario_movimiento_cuarto_frio_id ON inventario_movimiento(cuarto_frio_id);
CREATE INDEX idx_inventario_movimiento_cosecha_id ON inventario_movimiento(cosecha_id);
CREATE INDEX idx_venta_cliente_id ON venta(cliente_id);
CREATE INDEX idx_venta_variedad_id ON venta(variedad_id);
CREATE INDEX idx_despacho_venta_id ON despacho(venta_id);
CREATE INDEX idx_despacho_aerolinea_id ON despacho(aerolinea_id);
CREATE INDEX idx_despacho_agencia_carga_id ON despacho(agencia_carga_id);