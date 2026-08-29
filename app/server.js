const express = require('express');
const { Pool } = require('pg');

const app = express();

const pool = new Pool({
  host: process.env.DB_HOST,
  port: 5432,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.get('/ready', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ready' });
  } catch (err) {
    console.error('readiness check failed:', err.message);
    res.status(503).json({ status: 'not ready' });
  }
});

app.get('/items', async (req, res) => {
  try {
    const result = await pool.query('SELECT 1 AS id, $1::text AS name', ['sample item']);
    res.json(result.rows);
  } catch (err) {
    console.error('items query failed:', err.message);
    res.status(503).json({ error: 'database unavailable' });
  }
});

module.exports = app;

if (require.main === module) {
  app.listen(3000, () => console.log('listening on 3000'));
}