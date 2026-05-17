import { json } from '@sveltejs/kit';
import { getDb } from '$lib/server/db';
import { mkdirSync, writeFileSync } from 'fs';
import { randomUUID } from 'crypto';
import bcrypt from 'bcryptjs';

export async function GET({ locals }) {
  if (!locals.user) return json({ error: 'Sign in required' }, { status: 401 });

  const db = getDb();
  const profile = db.prepare('SELECT id, email, display_name, avatar_url, created_at FROM profiles WHERE id = ?').get(locals.user.id) as any;

  const postCount = db.prepare('SELECT COUNT(*) as c FROM posts WHERE user_id = ?').get(locals.user.id) as any;
  const followerCount = db.prepare('SELECT COUNT(*) as c FROM follows WHERE following_id = ?').get(locals.user.id) as any;
  const followingCount = db.prepare('SELECT COUNT(*) as c FROM follows WHERE follower_id = ?').get(locals.user.id) as any;

  return json({
    ...profile,
    posts_count: postCount.c,
    followers_count: followerCount.c,
    following_count: followingCount.c
  });
}

export async function POST({ request, locals }) {
  if (!locals.user) return json({ error: 'Sign in required' }, { status: 401 });

  const form = await request.formData();
  const displayName = form.get('display_name') as string;
  const avatarFile = form.get('avatar') as File | null;
  const password = form.get('password') as string | null;

  const db = getDb();

  if (displayName) {
    db.prepare('UPDATE profiles SET display_name = ? WHERE id = ?').run(displayName, locals.user.id);
  }

  if (avatarFile && avatarFile.size > 0) {
    mkdirSync('data/images', { recursive: true });
    const buf = Buffer.from(await avatarFile.arrayBuffer());
    const ext = avatarFile.name.split('.').pop() || 'jpg';
    const filename = `avatar-${locals.user.id}.${ext}`;
    writeFileSync(`data/images/${filename}`, buf);
    const url = `/api/images/${filename}`;
    db.prepare('UPDATE profiles SET avatar_url = ? WHERE id = ?').run(url, locals.user.id);
  }

  if (password && password.length >= 6) {
    const hash = await bcrypt.hash(password, 10);
    db.prepare('UPDATE profiles SET password_hash = ? WHERE id = ?').run(hash, locals.user.id);
  }

  const profile = db.prepare('SELECT id, email, display_name, avatar_url FROM profiles WHERE id = ?').get(locals.user.id);
  return json(profile);
}
