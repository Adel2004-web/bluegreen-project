const express = require('express');
const client = require('prom-client');

const app = express();
const VERSION = process.env.APP_VERSION || 'dev';
const COLOR = process.env.APP_COLOR || 'unknown';

client.collectDefaultMetrics();
new client.Gauge({
  name: 'app_info', help: 'Version and color of the running app',
  labelNames: ['version', 'color'],
}).set({ version: VERSION, color: COLOR }, 1);
const httpDuration = new client.Histogram({
  name: 'http_request_duration_seconds', help: 'HTTP request duration',
  labelNames: ['method', 'route', 'status'],
});

app.use((req, res, next) => {
  const end = httpDuration.startTimer();
  res.on('finish', () => end({ method: req.method, route: req.path, status: res.statusCode }));
  next();
});

app.get('/', (req, res) => res.json({ message: 'Hello from blue-green demo', version: VERSION, color: COLOR }));
app.get('/health', (req, res) => res.json({ status: 'ok', version: VERSION, color: COLOR }));
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});

const server = app.listen(3000, () => console.log(`[${COLOR}] v${VERSION} listening on :3000`));
process.on('SIGTERM', () => server.close(() => process.exit(0)));
