const aedes = require('aedes')();
const { WebSocketServer, createWebSocketStream } = require('ws');
const wss = new WebSocketServer({ host: '127.0.0.1', port: 9001, path: '/mqtt' });
wss.on('connection', ws => aedes.handle(createWebSocketStream(ws)));
console.log('broker up');
