<?php
// Conexión a la base de datos del inventario. La usan equipos.php, equipo.php y buscar.php.
// ⚠️ ASÍ VIENE: entra como ROOT, y con la contraseña escrita aquí (este fichero acaba en Git, en un pendrive…).
declare(strict_types=1);

// 👀 Lee un fichero de variables «CLAVE=valor» (el mismo inventario.env que usa Python) y lo devuelve como array.
//    Se salta las líneas vacías y los comentarios (#). Ejemplo: leer_env('/etc/inventario/inventario.env')['DB_NAME'] → 'inventario'
function leer_env(string $fichero): array
{
    $cfg = [];
    foreach (file($fichero, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $linea) {
        if (str_starts_with(trim($linea), '#') || !str_contains($linea, '=')) {
            continue;
        }
        [$clave, $valor] = explode('=', $linea, 2);
        $cfg[trim($clave)] = trim($valor);
    }
    return $cfg;
}

// ✍️ 2.2 Que conecte con los datos de /etc/inventario/inventario.env (el servidor/inventario.env de tu kit):
//        - lee el fichero con leer_env y guárdalo en $cfg;
//        - el DSN, con el host y la base de $cfg (no escritos a mano);
//        - el usuario y la contraseña, de $cfg. Al final, ni 'root' ni ninguna contraseña escrita en este fichero.
function conectar(): PDO
{
    $dsn = 'mysql:host=db;dbname=inventario;charset=utf8mb4';
    return new PDO($dsn, 'root', 'raiz-de-la-bateria', [
        PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,   // si algo falla, que avise (excepción)
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,         // cada fila, un array con los nombres de columna
    ]);
}
