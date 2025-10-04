import jwt from 'jsonwebtoken';

export function requireAuth(req, res, next) {
  const auth = req.headers.authorization || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Missing Bearer token' });
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    req.user = { id: payload.sub, email: payload.email };
    next();
  } catch {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

export function requireSameUserFromBody(key = 'user_id') {
  return (req, res, next) => {
    if (!req.user?.id) return res.status(401).json({ error: 'Unauthenticated' });
    if (req.body?.[key] !== req.user.id) {
      return res.status(403).json({ error: 'Forbidden: user mismatch' });
    }
    next();
  };
}

export function requireSameUserFromParam(param = 'id') {
  return (req, res, next) => {
    if (!req.user?.id) return res.status(401).json({ error: 'Unauthenticated' });
    if (req.params?.[param] !== req.user.id) {
      return res.status(403).json({ error: 'Forbidden: user mismatch' });
    }
    next();
  };
}