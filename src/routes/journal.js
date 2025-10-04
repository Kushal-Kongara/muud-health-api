import { Router } from 'express';
import pool from '../db.js';
import {
  validateJournalEntry,
  validateUserIdParam,
} from '../middleware/validate.js';
import {
  requireAuth,
  requireSameUserFromBody,
  requireSameUserFromParam,
} from '../middleware/auth.js';

const router = Router();

/**
 * POST /journal/entry
 * body: { user_id(UUID), entry_text(string), mood_rating(1-5), timestamp(optional ISO) }
 * Auth required; body.user_id must match token user
 */
router.post(
  '/entry',
  requireAuth,
  validateJournalEntry,
  requireSameUserFromBody('user_id'),
  async (req, res) => {
    try {
      const { user_id, entry_text, mood_rating, timestamp } = req.body;
      if (timestamp) {
        const q = `
          INSERT INTO journal_entries (user_id, entry_text, mood_rating, timestamp)
          VALUES ($1, $2, $3, $4::timestamptz)
          RETURNING id;
        `;
        const { rows } = await pool.query(q, [
          user_id,
          entry_text,
          Number(mood_rating),
          timestamp,
        ]);
        return res.status(201).json({ success: true, id: rows[0].id });
      } else {
        const q = `
          INSERT INTO journal_entries (user_id, entry_text, mood_rating)
          VALUES ($1, $2, $3)
          RETURNING id;
        `;
        const { rows } = await pool.query(q, [
          user_id,
          entry_text,
          Number(mood_rating),
        ]);
        return res.status(201).json({ success: true, id: rows[0].id });
      }
    } catch (err) {
      console.error('POST /journal/entry error:', err);
      return res
        .status(500)
        .json({ success: false, error: 'Failed to create journal entry' });
    }
  }
);

/**
 * GET /journal/user/:id
 * Auth required; :id must match token user
 */
router.get(
  '/user/:id',
  requireAuth,
  validateUserIdParam,
  requireSameUserFromParam('id'),
  async (req, res) => {
    try {
      const userId = req.params.id;
      const q = `
        SELECT id, user_id, entry_text, mood_rating, timestamp
        FROM journal_entries
        WHERE user_id = $1
        ORDER BY timestamp DESC, id DESC;
      `;
      const { rows } = await pool.query(q, [userId]);
      return res.json({ success: true, entries: rows });
    } catch (err) {
      console.error('GET /journal/user/:id error:', err);
      return res
        .status(500)
        .json({ success: false, error: 'Failed to fetch journal entries' });
    }
  }
);

export default router;