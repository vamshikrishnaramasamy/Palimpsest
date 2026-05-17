import { json } from '@sveltejs/kit';
import { getDb } from '$lib/server/db';
import { createToken } from '$lib/server/auth';
import bcrypt from 'bcryptjs';
import { randomUUID } from 'crypto';

export async function POST({ request, cookies }) {
  const { email, password, display_name } = await request.json();

  if (!email || !password || password.length < 6) {
    return json({ error: 'Email and password (6+ chars) required' }, { status: 400 });
  }

  const db = getDb();
  const existing = db.prepare('SELECT id FROM profiles WHERE email = ?').get(email);

  if (existing) {
    return json({ error: 'Email already registered' }, { status: 409 });
  }

  const id = randomUUID();
  const hash = await bcrypt.hash(password, 10);
  const displayName = String(display_name || email.split('@')[0])
    .replace(/[._-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/\b\w/g, (char) => char.toUpperCase()) || 'New Visitor';

  db.prepare('INSERT INTO profiles (id, email, password_hash, display_name) VALUES (?, ?, ?, ?)').run(id, email, hash, displayName);

  const token = await createToken(id, email);
  cookies.set('token', token, {
    path: '/',
    httpOnly: true,
    sameSite: 'lax',
    maxAge: 60 * 60 * 24 * 7
  });

  return json({ user: { id, email, display_name: displayName, avatar_url: null }, token });
}
