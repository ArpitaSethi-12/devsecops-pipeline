const app = require('./app');
const { init, pool } = require('./db');

const port = Number(process.env.PORT) || 3000;

init()
  .then(() => {
    const server = app.listen(port, () => {
      console.log(`API listening on port ${port}`);
    });
    const shutdown = () => {
      server.close(() => pool.end().then(() => process.exit(0)));
    };
    process.on('SIGTERM', shutdown);
    process.on('SIGINT', shutdown);
  })
  .catch((err) => {
    console.error('Failed to start:', err.message);
    process.exit(1);
  });
