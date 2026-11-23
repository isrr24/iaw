-- Se ejecuta UNA vez, la primera vez que arranca MariaDB (el volumen «datos» está vacío).
-- La base «inventario» ya la crea MARIADB_DATABASE. Aquí: los equipos del aula, el profesorado y un usuario de ejemplo.
-- No lo cambies: lo tuyo va en sql/bloque1.sql.
USE inventario;

CREATE TABLE equipos (
  id     INT AUTO_INCREMENT PRIMARY KEY,
  codigo VARCHAR(20) NOT NULL UNIQUE,     -- la pegatina del equipo
  tipo   VARCHAR(30) NOT NULL,
  aula   VARCHAR(10) NOT NULL,
  estado VARCHAR(20) NOT NULL DEFAULT 'funciona'
);
INSERT INTO equipos (codigo, tipo, aula, estado) VALUES
  ('PC-A12-01', 'ordenador',  'A12', 'funciona'),
  ('PC-A12-02', 'ordenador',  'A12', 'averiado'),
  ('PC-A12-03', 'ordenador',  'A12', 'funciona'),
  ('PRY-A12',   'proyector',  'A12', 'funciona'),
  ('PC-B03-01', 'ordenador',  'B03', 'funciona'),
  ('PC-B03-02', 'ordenador',  'B03', 'funciona'),
  ('IMP-B03',   'impresora',  'B03', 'sin tóner'),
  ('SW-RACK',   'switch',     'CPD', 'funciona');

CREATE TABLE profesorado (
  id      INT AUTO_INCREMENT PRIMARY KEY,
  usuario VARCHAR(30)  NOT NULL UNIQUE,
  clave   VARCHAR(255) NOT NULL,           -- el hash de la contraseña, nunca la contraseña
  email   VARCHAR(100) NOT NULL
);
INSERT INTO profesorado (usuario, clave, email) VALUES
  ('jefatura', '$2y$10$Qm4nB7vC1xZ9lK3jH5gF7dS9aP2oI4uY6tR8eW0qM2nB4vC6xZ8lK', 'jefatura@inventario.iaw.local'),
  ('tic',      '$2y$10$Wd3fG5hJ7kL9zX1cV3bN5mQ7wE9rT1yU3iO5pA7sD9fG1hJ3kL5zX', 'tic@inventario.iaw.local'),
  ('secretaria','$2y$10$Pl0oK9iJ8uH7yG6tF5rD4eS3wA2qZ1xC0vB9nM8lK7jH6gF5dS4aQ', 'secretaria@inventario.iaw.local');

-- 👀 Ejemplo resuelto (bloque 1): un usuario que SOLO puede leer, y solo en esta base.
CREATE USER 'inv_lector'@'%' IDENTIFIED BY 'solo-mirar-2026';
GRANT SELECT ON inventario.* TO 'inv_lector'@'%';
