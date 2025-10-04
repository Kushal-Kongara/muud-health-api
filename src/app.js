import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import pool from './db.js';
import journalRouter from './routes/journal.js';
import contactsRouter from './routes/contacts.js';
import authRouter from './routes/auth.js';
import { requireAuth } from './middleware/auth.js';

const app = express();
app.use(cors());
app.use(express.json());

app.use('/journal', journalRouter);
app.use('/contacts', contactsRouter);
app.use('/auth', authRouter);

// health
app.get('/health', async (_req, res) => {
  try {
    const { rows } = await pool.query('SELECT NOW() as now');
    res.json({ ok: true, db_time: rows[0].now });
  } catch {
    res.status(500).json({ ok: false, error: 'DB connection failed' });
  }
});

// protected test route
app.get('/me', requireAuth, (req, res) => {
  res.json({ ok: true, user: req.user });
});

export default app;