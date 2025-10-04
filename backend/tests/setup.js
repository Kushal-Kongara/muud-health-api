import pool from '../src/db.js';

afterAll(async () => {
  // Close the Postgres pool so Jest can exit cleanly
  await pool.end().catch(() => {});
});