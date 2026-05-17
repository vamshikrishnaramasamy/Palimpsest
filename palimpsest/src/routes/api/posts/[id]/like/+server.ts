import { json } from '@sveltejs/kit';
import { getDb } from '$lib/server/db';

export async function POST({ params, locals }) {
  if (!locals.user) return json({ error: 'Sign in required' }, { status: 401 });

  const db = getDb();
  const existing = db.prepare('SELECT 1 FROM likes WHERE user_id = ? AND post_id = ?').get(locals.user.id, params.id);

  if (existing) {
    db.prepare('DELETE FROM likes WHERE user_id = ? AND post_id = ?').run(locals.user.id, params.id);
    return json({ liked: false });
  } else {
    db.prepare('INSERT INTO likes (user_id, post_id) VALUES (?, ?)').run(locals.user.id, params.id);
    return json({ liked: true });
  }
}
