const express = require('express');
const { pool } = require('./db');
const users = require('./users');

const app = express();
app.disable('x-powered-by');
app.use(express.json({ limit: '10kb' }));

app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', version: process.env.APP_VERSION || 'dev' });
  } catch {
    res.status(503).json({ status: 'database unavailable' });
  }
});

app.get('/api/users', async (req, res) => {
  res.json(await users.listUsers());
});

app.get('/api/users/search', async (req, res) => {
  const name = String(req.query.name || '').trim();
  if (!name) return res.status(400).json({ error: 'name is required' });
  res.json(await users.searchUsers(name));
});

app.get('/api/users/:id', async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id < 1) {
    return res.status(400).json({ error: 'id must be a positive number' });
  }
  const user = await users.getUser(id);
  if (!user) return res.status(404).json({ error: 'user not found' });
  res.json(user);
});

app.post('/api/users', async (req, res) => {
  const { name, email } = req.body || {};
  if (typeof name !== 'string' || !name.trim()) {
    return res.status(400).json({ error: 'name is required' });
  }
  if (typeof email !== 'string' || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    return res.status(400).json({ error: 'a valid email is required' });
  }
  try {
    const user = await users.createUser(name.trim(), email.toLowerCase());
    res.status(201).json(user);
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ error: 'email already exists' });
    }
    throw err;
  }
});

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'something went wrong' });
});

module.exports = app;
