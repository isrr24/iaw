<?php
// Buscador de equipos por aula: buscar.php?aula=A12
declare(strict_types=1);
require __DIR__ . '/inc/db.php';
require __DIR__ . '/inc/cabecera.php';

$aula = $_GET['aula'] ?? '';
$pdo  = conectar();
// ⚠️ ASÍ VIENE: lo que escribe el usuario se PEGA dentro del SQL → inyección SQL.
// ✍️ 3.1 Consulta preparada, como en equipo.php: el SQL con un ? en lugar de '$aula', y el dato en execute([…]).
$sql       = "SELECT codigo, tipo, aula, estado FROM equipos WHERE aula = '$aula' ORDER BY codigo";
$resultado = $pdo->query($sql)->fetchAll();
?>
<h2>Buscar por aula</h2>
<form><input name="aula" value="<?= e($aula) ?>" placeholder="A12"> <button>Buscar</button></form>
<ul id="resultados">
<?php foreach ($resultado as $q): ?>
  <li><?= e((string) $q['codigo']) ?> — <?= e((string) $q['tipo']) ?> · <?= e((string) $q['aula']) ?> · <?= e((string) $q['estado']) ?></li>
<?php endforeach; ?>
</ul>
</body></html>
