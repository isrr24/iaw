# Explícalo con tus palabras

Cuando tengas el comprobador en verde, contesta aquí sin mirar los apuntes (2–4 líneas cada una).
Es lo que te preguntarán en la defensa de la práctica.

1. ¿Por qué la web no entra en MariaDB como `root`? ¿Qué quiere decir `'inv_web'@'%'` y por qué no `'inv_web'@'localhost'`?

2. ¿Dónde va la contraseña de la base de datos y por qué no en `db.php`? ¿Cuándo la lee PHP y cuándo Python?

3. Explica qué hace cada trozo de `x' UNION SELECT usuario, clave, email, 'x' FROM profesorado -- -` y por qué con una consulta preparada no funciona.

4. ¿Cómo sabes que una copia de seguridad sirve? ¿Qué no guarda `mysqldump` de la base de datos?

5. Has subido `inventario.env` a Git por error. ¿Basta con borrarlo en otro commit? ¿Qué haces? ¿Y qué diferencia hay entre `git restore` y `git revert`?
