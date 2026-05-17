import { json } from '@sveltejs/kit';
import { getDb } from '$lib/server/db';

export async function GET({ url }) {
  const q = url.searchParams.get('q') || '';
  if (!q) return json([]);

  const db = getDb();
  const rows = db.prepare(
    'SELECT id, email, display_name, avatar_url FROM profiles WHERE email LIKE ? OR display_name LIKE ? LIMIT 10'
  ).all(`%${q}%`, `%${q}%`);

  return json(rows);
}
