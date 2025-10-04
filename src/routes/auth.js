import { Router } from 'express';
import pool from '../db.js';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { randomUUID } from 'crypto';

const router = Router();

function isEmail(v) { return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v || ''); }
function signToken(user) {
  return jwt.sign({ sub: user.id, email: user.email }, process.env.JWT_SECRET, { expiresIn: '7d' });
}

/** POST /auth/register  { email, password, name? } */
router.post('/register', async (req, res) => {
  try {
    const { email, password, name } = req.body || {};
    if (!isEmail(email)) return res.status(400).json({ error: 'Valid email required' });
    if (typeof password !== 'string' || password.length < 6)
      return res.status(400).json({ error: 'Password must be >= 6 chars' });

    const exists = await pool.query('SELECT id FROM users WHERE email=$1', [email.toLowerCase()]);
    if (exists.rowCount) return res.status(409).json({ error: 'Email already registered' });

    const id = randomUUID();
    const password_hash = await bcrypt.hash(password, 10);
    await pool.query(
      'INSERT INTO users (id, email, password_hash, name) VALUES ($1,$2,$3,$4)',
      [id, email.toLowerCase(), password_hash, name || null]
    );

    const token = signToken({ id, email: email.toLowerCase() });
    return res.status(201).json({ success: true, token, user: { id, email: email.toLowerCase(), name: name || null } });
  } catch (e) {
    console.error('POST /auth/register', e);
    return res.status(500).json({ error: 'Registration failed' });
  }
});

/** POST /auth/login  { email, password } */
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body || {};
    if (!isEmail(email)) return res.status(400).json({ error: 'Valid email required' });
    const { rows } = await pool.query('SELECT id, email, password_hash, name FROM users WHERE email=$1', [email.toLowerCase()]);
    if (!rows.length) return res.status(401).json({ error: 'Invalid credentials' });

    const user = rows[0];
    const ok = await bcrypt.compare(password || '', user.password_hash);
    if (!ok) return res.status(401).json({ error: 'Invalid credentials' });

    const token = signToken({ id: user.id, email: user.email });
    return res.json({ success: true, token, user: { id: user.id, email: user.email, name: user.name } });
  } catch (e) {
    console.error('POST /auth/login', e);
    return res.status(500).json({ error: 'Login failed' });
  }
});

export default router;