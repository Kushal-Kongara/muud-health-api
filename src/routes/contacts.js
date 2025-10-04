import { Router } from 'express';
import pool from '../db.js';
import {
  validateContact,
  validateUserIdParam,
} from '../middleware/validate.js';
import {
  requireAuth,
  requireSameUserFromBody,
  requireSameUserFromParam,
} from '../middleware/auth.js';

const router = Router();

/**
 * POST /contacts/add
 * body: { user_id(UUID), contact_name(string), contact_email(email) }
 * Auth required; body.user_id must match token user
 */
router.post(
  '/add',
  requireAuth,
  validateContact,
  requireSameUserFromBody('user_id'),
  async (req, res) => {
    try {
      const { user_id, contact_name, contact_email } = req.body;
      const q = `
        INSERT INTO contacts (user_id, contact_name, contact_email)
        VALUES ($1, $2, $3)
        RETURNING id;
      `;
      const { rows } = await pool.query(q, [
        user_id,
        contact_name.trim(),
        contact_email.toLowerCase(),
      ]);
      return res.status(201).json({ success: true, id: rows[0].id });
    } catch (err) {
      console.error('POST /contacts/add error:', err);
      return res
        .status(500)
        .json({ success: false, error: 'Failed to add contact' });
    }
  }
);

/**
 * GET /contacts/user/:id
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
        SELECT id, user_id, contact_name, contact_email, created_at
        FROM contacts
        WHERE user_id = $1
        ORDER BY created_at DESC, id DESC;
      `;
      const { rows } = await pool.query(q, [userId]);
      return res.json({ success: true, contacts: rows });
    } catch (err) {
      console.error('GET /contacts/user/:id error:', err);
      return res
        .status(500)
        .json({ success: false, error: 'Failed to fetch contacts' });
    }
  }
);

export default router;