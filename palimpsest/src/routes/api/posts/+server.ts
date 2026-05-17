import { json } from '@sveltejs/kit';
import { getDb } from '$lib/server/db';
import { randomUUID } from 'crypto';
import { writeFileSync, mkdirSync } from 'fs';

export async function GET({ url, locals }) {
  const tab = url.searchParams.get('tab') || 'for_you';
  const limit = parseInt(url.searchParams.get('limit') || '20');
  const before = url.searchParams.get('before');

  const db = getDb();

  let rows: any[];
  const visibleWhere = locals.user
    ? '(p.is_private = 0 OR p.user_id = ?)'
    : 'p.is_private = 0';
  const visibleArgs = locals.user ? [locals.user.id] : [];
  if (tab === 'favorites' && locals.user) {
    rows = db.prepare(`
      SELECT p.*, pr.display_name, pr.email, pr.avatar_url,
        (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id) as like_count,
        (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id) as comment_count,
        1 as liked_by_me,
        (SELECT COUNT(*) FROM follows f2 WHERE f2.follower_id = ? AND f2.following_id = p.user_id) as is_following_author
      FROM posts p
      JOIN profiles pr ON p.user_id = pr.id
      JOIN likes mine ON mine.post_id = p.id AND mine.user_id = ?
      WHERE ${visibleWhere}
      ${before ? 'AND p.created_at < ?' : ''}
      ORDER BY mine.created_at DESC
      LIMIT ?
    `).all(...(before ? [locals.user.id, locals.user.id, ...visibleArgs, before, limit] : [locals.user.id, locals.user.id, ...visibleArgs, limit]));
  } else if (tab === 'following' && locals.user) {
    rows = db.prepare(`
      SELECT p.*, pr.display_name, pr.email, pr.avatar_url,
        (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id) as like_count,
        (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id) as comment_count,
        (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id AND l.user_id = ?) as liked_by_me,
        1 as is_following_author
      FROM posts p
      JOIN profiles pr ON p.user_id = pr.id
      JOIN follows f ON f.following_id = p.user_id
      WHERE f.follower_id = ?
      AND ${visibleWhere}
      ${before ? 'AND p.created_at < ?' : ''}
      ORDER BY p.created_at DESC
      LIMIT ?
    `).all(...(before ? [locals.user.id, locals.user.id, ...visibleArgs, before, limit] : [locals.user.id, locals.user.id, ...visibleArgs, limit]));
  } else if (tab === 'map' && locals.user) {
    rows = db.prepare(`
      SELECT p.*, pr.display_name, pr.email, pr.avatar_url,
        (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id) as like_count,
        (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id) as comment_count,
        (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id AND l.user_id = ?) as liked_by_me,
        (SELECT COUNT(*) FROM follows f2 WHERE f2.follower_id = ? AND f2.following_id = p.user_id) as is_following_author
      FROM posts p
      JOIN profiles pr ON p.user_id = pr.id
      WHERE ${visibleWhere}
      AND p.lat IS NOT NULL AND p.lng IS NOT NULL
      ORDER BY p.created_at DESC
      LIMIT ?
    `).all(locals.user.id, locals.user.id, ...visibleArgs, limit);
  } else {
    rows = db.prepare(`
      SELECT p.*, pr.display_name, pr.email, pr.avatar_url,
        (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id) as like_count,
        (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id) as comment_count,
        ${locals.user ? "(SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id AND l.user_id = ?) as liked_by_me" : '0 as liked_by_me'},
        ${locals.user ? "(SELECT COUNT(*) FROM follows f2 WHERE f2.follower_id = ? AND f2.following_id = p.user_id) as is_following_author" : '0 as is_following_author'}
      FROM posts p
      JOIN profiles pr ON p.user_id = pr.id
      WHERE ${visibleWhere}
      ${before ? 'AND p.created_at < ?' : ''}
      ORDER BY p.created_at DESC
      LIMIT ?
    `).all(...(locals.user
      ? (before ? [locals.user.id, locals.user.id, ...visibleArgs, before, limit] : [locals.user.id, locals.user.id, ...visibleArgs, limit])
      : (before ? [before, limit] : [limit])));
  }

  const posts = rows.map((r: any) => ({
    ...r,
    liked_by_me: r.liked_by_me > 0,
    is_private: r.is_private > 0,
    is_following_author: r.is_following_author > 0
  }));

  return json(posts);
}

export async function POST({ request, locals }) {
  if (!locals.user) return json({ error: 'Sign in required' }, { status: 401 });

  const form = await request.formData();
  const body = form.get('body') as string;
  const mediaFile = (form.get('media_0') as File | null) || (form.get('image') as File | null);
  const lng = form.get('lng') ? parseFloat(form.get('lng') as string) : null;
  const lat = form.get('lat') ? parseFloat(form.get('lat') as string) : null;
  const isPrivate = form.get('is_private') === 'true' || form.get('is_private') === '1';

  const id = randomUUID();
  let imageUrl: string | null = null;

  if (mediaFile && mediaFile.size > 0) {
    mkdirSync('data/images', { recursive: true });
    const buf = Buffer.from(await mediaFile.arrayBuffer());
    const ext = safeExtension(mediaFile.name, mediaFile.type);
    const filename = `${id}.${ext}`;
    writeFileSync(`data/images/${filename}`, buf);
    imageUrl = `/api/images/${filename}`;
  }

  const db = getDb();
  db.prepare('INSERT INTO posts (id, user_id, body, image_url, lng, lat, is_private) VALUES (?, ?, ?, ?, ?, ?, ?)').run(id, locals.user.id, body, imageUrl, lng, lat, isPrivate ? 1 : 0);

  const post = db.prepare(`
    SELECT p.*, pr.display_name, pr.email, pr.avatar_url, 0 as like_count, 0 as comment_count, 0 as liked_by_me, 0 as is_following_author
    FROM posts p JOIN profiles pr ON p.user_id = pr.id WHERE p.id = ?
  `).get(id);

  return json(post);
}

function safeExtension(name: string, type: string): string {
  const ext = name.split('.').pop()?.toLowerCase().replace(/[^a-z0-9]/g, '');
  if (ext) return ext;

  const byMime: Record<string, string> = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/gif': 'gif',
    'image/webp': 'webp',
    'video/mp4': 'mp4',
    'video/quicktime': 'mov',
    'audio/mpeg': 'mp3',
    'audio/mp4': 'm4a',
    'audio/x-m4a': 'm4a',
    'audio/wav': 'wav',
    'audio/x-wav': 'wav',
    'audio/aac': 'aac'
  };

  return byMime[type] ?? 'bin';
}
