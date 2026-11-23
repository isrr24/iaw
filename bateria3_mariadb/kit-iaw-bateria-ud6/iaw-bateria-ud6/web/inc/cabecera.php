<?php declare(strict_types=1);
function e(string $t): string { return htmlspecialchars($t, ENT_QUOTES, 'UTF-8'); }   // lo de la UD4: escapar al imprimir
?><!doctype html>
<html lang="es"><head><meta charset="utf-8"><title>Inventario del aula</title><link rel="stylesheet" href="/estilo.css"></head>
<body><header><h1>🖥️ Inventario del aula</h1>
<nav><a href="/equipos.php">Equipos</a> · <a href="/buscar.php">Buscar por aula</a> · <a href="/api/equipos">API</a></nav></header>
