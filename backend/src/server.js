import { createApp } from './app.js';
import { loadConfig } from './config.js';
import { createDatabase } from './database.js';

const config = loadConfig();
const db = createDatabase(config.databaseUrl);
const app = createApp({ db, jwtSecret: config.jwtSecret });
const server = app.listen(config.port, () => console.log(`CSW430 API listening on http://localhost:${config.port}`));

async function shutdown() {
  server.close(async () => { await db.close(); process.exit(0); });
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
