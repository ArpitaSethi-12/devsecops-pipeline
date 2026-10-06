const express = require('express');
const { rateLimit } = require('express-rate-limit');
const { pool } = require('./db');
const users = require('./users');

const app = express();
app.disable('x-powered-by');
app.use(express.json({ limit: '10kb' }));

// Limit each client to 100 requests per minute
app.use(
  rateLimit({
    windowMs: 60 * 1000,
    limit: 100,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
  }),
);

// Checks email shape without a regex, so a long crafted input can't slow the server down
function isValidEmail(email) {
  if (email.length > 254 || /\s/.test(email)) return false;
  const at = email.indexOf('@');
  if (at < 1 || at !== email.lastIndexOf('@')) return false;
  const domain = email.slice(at + 1);
  const dot = domain.lastIndexOf('.');
  return dot > 0 && dot < domain.length - 1;
}

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
  if (typeof email !== 'string' || !isValidEmail(email)) {
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
