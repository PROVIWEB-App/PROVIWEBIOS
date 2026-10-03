const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 3000;
const HTML_FILE = path.join(__dirname, 'index.html');

const server = http.createServer((req, res) => {
    fs.readFile(HTML_FILE, (err, data) => {
        if (err) {
            res.writeHead(500, { 'Content-Type': 'text/plain' });
            res.end('Error cargando el simulador interactivo.');
            return;
        }
        res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
        res.end(data);
    });
});

server.listen(PORT, () => {
    console.log(`\n======================================================`);
    console.log(`🚀 PROVIWEB iOS — Simulador Interactivo Corriendo`);
    console.log(`🌐 Abre en tu navegador: http://localhost:${PORT}`);
    console.log(`======================================================\n`);
});
