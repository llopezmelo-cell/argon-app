const CACHE = 'argon-v6';

// Archivos que se cachean en la instalación
const PRECACHE = [
  './index.html',
  './manifest.json',
  './icon-192.png',
  './icon-512.png',
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c =>
      // Cachear shell de la app (ignorar errores individuales)
      Promise.allSettled(PRECACHE.map(url => c.add(url)))
    )
  );
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);

  // API de archivos → solo funciona en red local, no cachear
  if (url.pathname.startsWith('/api/')) {
    e.respondWith(
      fetch(e.request).catch(() =>
        new Response(JSON.stringify({ error: 'offline' }), {
          status: 503,
          headers: { 'Content-Type': 'application/json' }
        })
      )
    );
    return;
  }

  // datos.json → red primero, caché como respaldo (datos frescos online, últimos datos offline)
  if (url.pathname.endsWith('/datos.json') || url.pathname.endsWith('datos.json')) {
    e.respondWith(
      fetch(e.request, { cache: 'no-store' })
        .then(response => {
          const clone = response.clone();
          caches.open(CACHE).then(c => c.put('./datos.json', clone));
          return response;
        })
        .catch(() =>
          caches.match('./datos.json').then(r => r ||
            new Response('{"clientes":[]}', {
              headers: { 'Content-Type': 'application/json' }
            })
          )
        )
    );
    return;
  }

  // index.html → red primero, caché como respaldo
  if (url.pathname === '/' || url.pathname.endsWith('/index.html') || url.pathname.endsWith('index.html')) {
    e.respondWith(
      fetch(e.request, { cache: 'no-store' })
        .then(response => {
          const clone = response.clone();
          caches.open(CACHE).then(c => c.put(e.request, clone));
          return response;
        })
        .catch(() => caches.match(e.request).then(r => r || caches.match('./index.html')))
    );
    return;
  }

  // Todo lo demás (iconos, manifest, fuentes) → caché primero, red como respaldo
  e.respondWith(
    caches.match(e.request).then(r =>
      r || fetch(e.request).then(response => {
        const clone = response.clone();
        caches.open(CACHE).then(c => c.put(e.request, clone));
        return response;
      })
    )
  );
});
