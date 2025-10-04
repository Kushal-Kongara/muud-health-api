import request from 'supertest';
import app from '../src/app.js';

describe('Journal & Contacts', () => {
  const email = `jc_${Date.now()}@example.com`;
  const password = 'secret123';
  let token, userId;

  beforeAll(async () => {
    const reg = await request(app)
      .post('/auth/register')
      .send({ email, password, name: 'JC' })
      .expect(201);

    token = reg.body.token;

    const me = await request(app)
      .get('/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    userId = me.body.user.id;
  });

  it('creates a journal entry', async () => {
    const res = await request(app)
      .post('/journal/entry')
      .set('Authorization', `Bearer ${token}`)
      .send({ user_id: userId, entry_text: 'Test entry', mood_rating: 4 })
      .expect(201);

    expect(res.body.success).toBe(true);
    expect(res.body.id).toBeDefined();
  });

  it('lists journal entries', async () => {
    const res = await request(app)
      .get(`/journal/user/${userId}`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(res.body.success).toBe(true);
    expect(Array.isArray(res.body.entries)).toBe(true);
    expect(res.body.entries.length).toBeGreaterThan(0);
  });

  it('adds a contact and lists contacts', async () => {
    const add = await request(app)
      .post('/contacts/add')
      .set('Authorization', `Bearer ${token}`)
      .send({ user_id: userId, contact_name: 'Dr. Jane', contact_email: 'jane@example.com' })
      .expect(201);

    expect(add.body.success).toBe(true);

    const list = await request(app)
      .get(`/contacts/user/${userId}`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(list.body.success).toBe(true);
    expect(Array.isArray(list.body.contacts)).toBe(true);
    expect(list.body.contacts.length).toBeGreaterThan(0);
  });
});