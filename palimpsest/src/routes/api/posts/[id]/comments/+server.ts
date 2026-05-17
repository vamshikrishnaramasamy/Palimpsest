import { json } from '@sveltejs/kit';
import { getDb } from '$lib/server/db';
import { randomUUID } from 'crypto';

export async function GET({ params }) {
  const db = getDb();
  const rows = db.prepare(`
    SELECT c.*, pr.display_name, pr.email
    FROM comments c
    JOIN profiles pr ON c.user_id = pr.id
    WHERE c.post_id = ?
    ORDER BY c.created_at ASC
  `).all(params.id);

  return json(rows);
}

export async function POST({ params, request, locals }) {
  if (!locals.user) return json({ error: 'Sign in required' }, { status: 401 });

  const { body } = await request.json();
  if (!body) return json({ error: 'Body required' }, { status: 400 });

  const id = randomUUID();
  const db = getDb();
  db.prepare('INSERT INTO comments (id, post_id, user_id, body) VALUES (?, ?, ?, ?)').run(id, params.id, locals.user.id, body);

  const comment = db.prepare(`
    SELECT c.*, pr.display_name, pr.email
    FROM comments c
    JOIN profiles pr ON c.user_id = pr.id
    WHERE c.id = ?
  `).get(id);

  return json(comment);
}
