import { json } from '@sveltejs/kit';
import { getDb } from '$lib/server/db';

export async function POST({ params, locals }) {
  if (!locals.user) return json({ error: 'Sign in required' }, { status: 401 });
  if (locals.user.id === params.id) return json({ error: 'Cannot follow yourself' }, { status: 400 });

  const db = getDb();
  const target = db.prepare('SELECT id FROM profiles WHERE id = ?').get(params.id);
  if (!target) return json({ error: 'User not found' }, { status: 404 });

  const existing = db.prepare('SELECT 1 FROM follows WHERE follower_id = ? AND following_id = ?').get(locals.user.id, params.id);

  if (existing) {
    db.prepare('DELETE FROM follows WHERE follower_id = ? AND following_id = ?').run(locals.user.id, params.id);
  } else {
    db.prepare('INSERT INTO follows (follower_id, following_id) VALUES (?, ?)').run(locals.user.id, params.id);
  }

  const followerCount = db.prepare('SELECT COUNT(*) as c FROM follows WHERE following_id = ?').get(params.id) as any;
  return json({ following: !existing, followers_count: followerCount.c });
}
