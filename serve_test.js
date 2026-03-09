// Simple local server to serve the Flutter web build for testing
const http = require('http');
const fs = require('fs');
const path = require('path');

const buildDir = 'C:/Users/Amine/OneDrive/Projects/family-planner-app/frontend_flutter/build/web';

const mimeTypes = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.png': 'image/png',
  '.wasm': 'application/wasm',
  '.ico': 'image/x-icon',
  '.map': 'application/json',
};

const server = http.createServer((req, res) => {
  let filePath = path.join(buildDir, req.url === '/' ? 'index.html' : req.url.split('?')[0]);

  // SPA: serve index.html for unmatched routes
  if (!fs.existsSync(filePath)) {
    filePath = path.join(buildDir, 'index.html');
  }

  const ext = path.extname(filePath);
  const mime = mimeTypes[ext] || 'application/octet-stream';

  try {
    const content = fs.readFileSync(filePath);
    res.writeHead(200, { 'Content-Type': mime });
    res.end(content);
  } catch (e) {
    res.writeHead(404);
    res.end('Not found');
  }
});

server.listen(8765, () => {
  console.log('Serving Flutter web build at http://localhost:8765');
});
