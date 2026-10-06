const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const app = require('../src/app');
const { init, pool } = require('../src/db');

let server;
let base;

before(async () => {
  await init();
  await pool.query('TRUNCATE users RESTART IDENTITY');
  server = app.listen(0);
  base = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  server.close();
  await pool.end();
});

const post = (path, body) =>
  fetch(base + path, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });

test('health check reports ok', async () => {
  const res = await fetch(`${base}/health`);
  assert.equal(res.status, 200);
  assert.equal((await res.json()).status, 'ok');
});

test('creates and fetches a user', async () => {
  const created = await post('/api/users', { name: 'Asha', email: 'asha@example.com' });
  assert.equal(created.status, 201);
  const user = await created.json();

  const res = await fetch(`${base}/api/users/${user.id}`);
  assert.equal(res.status, 200);
  assert.equal((await res.json()).email, 'asha@example.com');
});

test('rejects invalid input', async () => {
  assert.equal((await post('/api/users', { name: '', email: 'x@y.com' })).status, 400);
  assert.equal((await post('/api/users', { name: 'Ravi', email: 'not-an-email' })).status, 400);
  assert.equal((await fetch(`${base}/api/users/abc`)).status, 400);
});

test('rejects duplicate email', async () => {
  await post('/api/users', { name: 'Ravi', email: 'ravi@example.com' });
  const res = await post('/api/users', { name: 'Ravi 2', email: 'ravi@example.com' });
  assert.equal(res.status, 409);
});

test('search finds users by name', async () => {
  const res = await fetch(`${base}/api/users/search?name=ash`);
  const rows = await res.json();
  assert.equal(rows.length, 1);
  assert.equal(rows[0].name, 'Asha');
});

test('search treats SQL as plain text', async () => {
  const res = await fetch(`${base}/api/users/search?name=${encodeURIComponent("' OR '1'='1")}`);
  assert.equal(res.status, 200);
  assert.equal((await res.json()).length, 0);
});

test('unknown user returns 404', async () => {
  assert.equal((await fetch(`${base}/api/users/9999`)).status, 404);
});
