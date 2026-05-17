import { json } from '@sveltejs/kit';
import { getDb } from '$lib/server/db';

export async function GET({ params, locals }) {
  if (!locals.user) return json({ error: 'Sign in required' }, { status: 401 });

  const db = getDb();
  const profile = db.prepare(`
    SELECT id, email, display_name, avatar_url, created_at
    FROM profiles
    WHERE id = ?
  `).get(params.id) as any;

  if (!profile) return json({ error: 'User not found' }, { status: 404 });

  const postCount = db.prepare('SELECT COUNT(*) as c FROM posts WHERE user_id = ?').get(params.id) as any;
  const followerCount = db.prepare('SELECT COUNT(*) as c FROM follows WHERE following_id = ?').get(params.id) as any;
  const followingCount = db.prepare('SELECT COUNT(*) as c FROM follows WHERE follower_id = ?').get(params.id) as any;
  const following = db.prepare('SELECT 1 FROM follows WHERE follower_id = ? AND following_id = ?').get(locals.user.id, params.id);

  return json({
    ...profile,
    posts_count: postCount.c,
    followers_count: followerCount.c,
    following_count: followingCount.c,
    followed_by_me: Boolean(following),
    is_me: locals.user.id === params.id
  });
}
