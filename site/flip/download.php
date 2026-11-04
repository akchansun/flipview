<?php
declare(strict_types=1);

$version = '0.6.16';
$file = 'Flip-' . $version . '-macos-universal.zip';
$local = __DIR__ . '/download/' . $file;
$github = 'https://github.com/akchansun/flipview/releases/download/v' . $version . '/' . $file;
$src = strtolower(trim((string) ($_GET['src'] ?? '')));

if ($src === 'gitee' || $src === 'github') {
    // Gitee has no 0.6.16 zip yet; both mirrors go to GitHub so users do not get 0.4.8.
    header('Location: ' . $github, true, 302);
    header('Cache-Control: no-store');
    exit;
}

$ctx = stream_context_create([
    'http' => [
        'method' => 'GET',
        'timeout' => 1,
        'ignore_errors' => true,
        'header' => "Host: www.ak129.cn\r\n",
    ],
]);
@file_get_contents('http://127.0.0.1/flip/stats.php?event=download', false, $ctx);

if (!is_file($local) || !is_readable($local)) {
    header('Location: ' . $github, true, 302);
    header('Cache-Control: no-store');
    exit;
}

$size = filesize($local);
header('Content-Type: application/zip');
header('Content-Disposition: attachment; filename="' . $file . '"');
header('Content-Length: ' . (string) $size);
header('Cache-Control: no-store');
readfile($local);
