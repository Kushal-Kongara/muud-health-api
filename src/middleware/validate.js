// Tiny, explicit validation helpers (no external library)
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const EMAIL_RE =
  /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function isUUID(v) { return typeof v === 'string' && UUID_RE.test(v); }
export function isEmail(v) { return typeof v === 'string' && EMAIL_RE.test(v); }

export function validateJournalEntry(req, res, next) {
  const { user_id, entry_text, mood_rating, timestamp } = req.body || {};
  if (!isUUID(user_id)) return res.status(400).json({ error: 'user_id must be a UUID' });
  if (typeof entry_text !== 'string' || !entry_text.trim())
    return res.status(400).json({ error: 'entry_text is required' });
  const mood = Number(mood_rating);
  if (!Number.isInteger(mood) || mood < 1 || mood > 5)
    return res.status(400).json({ error: 'mood_rating must be an integer 1-5' });
  if (timestamp !== undefined) {
    const d = new Date(timestamp);
    if (isNaN(d.getTime())) return res.status(400).json({ error: 'timestamp must be ISO date or omit it' });
  }
  next();
}

export function validateUserIdParam(req, res, next) {
  const id = req.params.id;
  if (!isUUID(id)) return res.status(400).json({ error: 'id must be a UUID' });
  next();
}

export function validateContact(req, res, next) {
  const { user_id, contact_name, contact_email } = req.body || {};
  if (!isUUID(user_id)) return res.status(400).json({ error: 'user_id must be a UUID' });
  if (typeof contact_name !== 'string' || !contact_name.trim())
    return res.status(400).json({ error: 'contact_name is required' });
  if (!isEmail(contact_email))
    return res.status(400).json({ error: 'contact_email must be a valid email' });
  next();
}