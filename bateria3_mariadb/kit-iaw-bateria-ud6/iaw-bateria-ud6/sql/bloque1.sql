-- Bloque 1 · Usuarios y permisos. Lo aplicas con: ./bateria.sh sql   (lo ejecuta como root, dentro del servidor)
-- Se puede aplicar las veces que quieras: cada orden está escrita para que no falle si ya se hizo antes.
USE inventario;

-- 👀 Así se crea un usuario de nuevo, desde cero (si ya existía, se borra antes con sus permisos):
--      DROP USER IF EXISTS 'inv_lector'@'%';
--      CREATE USER 'inv_lector'@'%' IDENTIFIED BY 'solo-mirar-2026';
--      GRANT SELECT ON inventario.* TO 'inv_lector'@'%';
--    (inv_lector ya existe: lo creó sql/01-inventario.sql al arrancar la base. No lo toques.)

-- ✍️ 1.2 El usuario de la web y de la API: inv_web, desde cualquier sitio ('%'), con una contraseña TUYA (apúntala:
--        la usas en el bloque 2). Puede leer, añadir y cambiar en la base inventario… y nada más.


-- ✍️ 1.3 La tabla incidencias (la usa el bloque 6). Cuatro columnas:
--        id          número que pone MariaDB solo, clave primaria
--        equipo_id   número entero, obligatorio
--        descripcion texto de hasta 200 caracteres, obligatorio
--        fecha       fecha y hora; si no se dice, la de ahora (DATETIME … DEFAULT CURRENT_TIMESTAMP)
--        Para que se pueda aplicar dos veces: CREATE TABLE IF NOT EXISTS.


-- ✍️ 1.4 root, solo desde el propio servidor: borra el root que entra desde cualquier sitio (sin que falle si ya no está).

