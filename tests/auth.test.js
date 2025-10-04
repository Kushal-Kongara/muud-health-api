import request from 'supertest';
import app from '../src/app.js';

describe('Auth flow', () => {
  const email = `user_${Date.now()}@example.com`;
  const password = 'secret123';

  it('registers and returns a token', async () => {
    const res = await request(app)
      .post('/auth/register')
      .send({ email, password, name: 'Kushal' })
      .expect(201);

    expect(res.body.success).toBe(true);
    expect(typeof res.body.token).toBe('string');
    expect(res.body.user.email).toBe(email.toLowerCase());
  });

  it('logs in and hits /me', async () => {
    const login = await request(app)
      .post('/auth/login')
      .send({ email, password })
      .expect(200);

    const token = login.body.token;
    expect(typeof token).toBe('string');

    const me = await request(app)
      .get('/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(me.body.ok).toBe(true);
    expect(me.body.user.email).toBe(email.toLowerCase());
  });
});