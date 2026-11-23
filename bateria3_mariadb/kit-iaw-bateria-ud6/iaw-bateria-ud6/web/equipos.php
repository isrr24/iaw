<?php
// Los equipos del aula, sacados de la base de datos.
declare(strict_types=1);
require __DIR__ . '/inc/db.php';
require __DIR__ . '/inc/cabecera.php';

$pdo     = conectar();
$equipos = $pdo->query('SELECT id, codigo, tipo, aula, estado FROM equipos ORDER BY aula, codigo')->fetchAll();
$yo      = $pdo->query('SELECT CURRENT_USER()')->fetchColumn();     // ¿con qué usuario estoy conectado?
?>
<h2>Equipos (<?= count($equipos) ?>)</h2>
<ul id="equipos">
<?php foreach ($equipos as $q): ?>
  <li><a href="/equipo.php?id=<?= (int) $q['id'] ?>"><?= e($q['codigo']) ?></a> — <?= e($q['tipo']) ?> · <?= e($q['aula']) ?> · <?= e($q['estado']) ?></li>
<?php endforeach; ?>
</ul>
<p class="nota" id="conexion">Conectado a la base de datos como: <?= e($yo) ?></p>
</body></html>
