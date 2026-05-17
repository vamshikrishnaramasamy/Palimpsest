import { json } from '@sveltejs/kit';
import { getDb } from '$lib/server/db';
import { createToken } from '$lib/server/auth';
import bcrypt from 'bcryptjs';

export async function POST({ request, cookies }) {
  const { email, password } = await request.json();

  if (!email || !password) {
    return json({ error: 'Email and password required' }, { status: 400 });
  }

  const db = getDb();
  const user = db.prepare('SELECT id, email, password_hash, display_name, avatar_url FROM profiles WHERE email = ?').get(email) as any;

  if (!user) {
    return json({ error: 'Invalid email or password' }, { status: 401 });
  }

  const valid = await bcrypt.compare(password, user.password_hash);
  if (!valid) {
    return json({ error: 'Invalid email or password' }, { status: 401 });
  }

  const token = await createToken(user.id, user.email);
  cookies.set('token', token, {
    path: '/',
    httpOnly: true,
    sameSite: 'lax',
    maxAge: 60 * 60 * 24 * 7
  });

  return json({
    user: {
      id: user.id,
      email: user.email,
      display_name: user.display_name,
      avatar_url: user.avatar_url
    },
    token
  });
}
