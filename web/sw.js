// sw.js — 利き将棋 Service Worker (PWA オフラインキャッシュ)
const CACHE_NAME = 'liki-shogi-v1';

// キャッシュするリソース
const PRECACHE_URLS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/flutter_bootstrap.js',
  '/favicon.png',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  '/icons/Icon-maskable-192.png',
  '/icons/Icon-maskable-512.png',
];

// インストール: 基本リソースをプリキャッシュ
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(PRECACHE_URLS).catch((err) => {
        console.warn('[SW] precache partial failure:', err);
      });
    })
  );
  self.skipWaiting();
});

// アクティベート: 古いキャッシュを削除
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k))
      )
    )
  );
  self.clients.claim();
});

// フェッチ: Cache-first (Flutter assets) + Network-first (API/CDN)
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // CDN リソース (YaneuraOu WASM) はネットワーク優先
  if (url.hostname.includes('cdn.jsdelivr.net')) {
    event.respondWith(
      fetch(event.request).catch(() => caches.match(event.request))
    );
    return;
  }

  // Flutter assets はキャッシュ優先
  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) return cached;
      return fetch(event.request).then((response) => {
        // 成功したレスポンスをキャッシュに追加
        if (
          response.ok &&
          event.request.method === 'GET' &&
          !url.pathname.includes('flutter_service_worker')
        ) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
        }
        return response;
      }).catch(() => {
        // オフライン時はキャッシュされたindex.htmlにフォールバック
        if (event.request.destination === 'document') {
          return caches.match('/index.html');
        }
      });
    })
  );
});
