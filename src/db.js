const { Pool } = require('pg');

const pool = new Pool({
  connectionString:
    process.env.DATABASE_URL || 'postgres://app:app@localhost:5432/app',
});

async function init() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL,
      email TEXT NOT NULL UNIQUE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
}

module.exports = { pool, init };
