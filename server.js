const http = require('http');
const fs   = require('fs');
const path = require('path');

const ROOT     = __dirname;
const CLIENTES = 'C:\\Users\\Luis\\OneDrive\\Favoritos\\CLIENTES';
const PORT     = 5500;
const HOST     = '0.0.0.0';   // escucha en toda la red local (WiFi)

const MIME = {
  html:'text/html', js:'application/javascript', json:'application/json',
  css:'text/css',   png:'image/png',              svg:'image/svg+xml',
  pdf:'application/pdf', jpg:'image/jpeg', jpeg:'image/jpeg',
  docx:'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  xlsx:'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  doc:'application/msword', xls:'application/vnd.ms-excel',
};

http.createServer((req, res) => {
  const urlObj = new URL(req.url, 'http://localhost');
  const pathname = urlObj.pathname;

  // Cabeceras CORS para localhost
  res.setHeader('Access-Control-Allow-Origin', '*');

  // ── Ruta /api/file?path=CLIENTE/carpeta/archivo.pdf ──
  if (pathname === '/api/file') {
    const rel = urlObj.searchParams.get('path');
    if (!rel) { res.writeHead(400); res.end('Falta el parámetro path'); return; }

    const abs = path.resolve(CLIENTES, rel);
    // Seguridad: solo sirve archivos dentro de CLIENTES
    if (!abs.startsWith(path.resolve(CLIENTES))) {
      res.writeHead(403); res.end('Acceso denegado'); return;
    }

    try {
      const data = fs.readFileSync(abs);
      const ext  = abs.split('.').pop().toLowerCase();
      const name = path.basename(abs);
      res.writeHead(200, {
        'Content-Type': MIME[ext] || 'application/octet-stream',
        'Content-Disposition': `inline; filename="${encodeURIComponent(name)}"`,
        'Content-Length': data.length,
      });
      res.end(data);
    } catch (e) {
      res.writeHead(404); res.end('Archivo no encontrado');
    }
    return;
  }

  // ── Archivos estáticos de la app ──
  const file = path.join(ROOT, pathname === '/' ? 'index.html' : pathname.split('?')[0]);
  try {
    const data = fs.readFileSync(file);
    const ext  = file.split('.').pop();
    res.writeHead(200, { 'Content-Type': MIME[ext] || 'text/plain' });
    res.end(data);
  } catch (e) {
    res.writeHead(404); res.end('Not found');
  }

}).listen(PORT, HOST, () => {
  console.log(`ARGon Admin corriendo en http://${HOST}:${PORT}`);
});
