const { pool } = require('./db');

async function listUsers() {
  const { rows } = await pool.query(
    'SELECT id, name, email FROM users ORDER BY id',
  );
  return rows;
}

async function getUser(id) {
  const { rows } = await pool.query(
    'SELECT id, name, email FROM users WHERE id = $1',
    [id],
  );
  return rows[0] || null;
}

async function createUser(name, email) {
  const { rows } = await pool.query(
    'INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id, name, email',
    [name, email],
  );
  return rows[0];
}

// Safe version: user input is passed as a parameter, never joined into the SQL string.
// Scenario 4 swaps this for an unsafe version to prove CodeQL blocks it.
async function searchUsers(name) {
  // Scenario 4: UNSAFE, user input is joined straight into the SQL string
  const { rows } = await pool.query(
    "SELECT id, name, email FROM users WHERE name ILIKE '%" + name + "%' ORDER BY id",
  );
  return rows;
}

module.exports = { listUsers, getUser, createUser, searchUsers };
