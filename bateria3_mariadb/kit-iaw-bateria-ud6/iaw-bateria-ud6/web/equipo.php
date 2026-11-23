<?php
// 👀 Ficha de un equipo: equipo.php?id=3. Ejemplo resuelto de consulta preparada (bloque 3).
declare(strict_types=1);
require __DIR__ . '/inc/db.php';
require __DIR__ . '/inc/cabecera.php';

$id  = $_GET['id'] ?? '';
$pdo = conectar();
$st  = $pdo->prepare('SELECT codigo, tipo, aula, estado FROM equipos WHERE id = ?');   // el SQL, con un hueco (?)
$st->execute([$id]);                                                                  // el dato, APARTE
$filas = $st->fetchAll();
?>
<h2>Ficha del equipo</h2>
<ul id="resultados">
<?php foreach ($filas as $q): ?>
  <li><?= e($q['codigo']) ?> — <?= e($q['tipo']) ?> · <?= e($q['aula']) ?> · <?= e($q['estado']) ?></li>
<?php endforeach; ?>
</ul>
<?php if (!$filas): ?><p class="nota">No hay ningún equipo con ese número.</p><?php endif; ?>
</body></html>
