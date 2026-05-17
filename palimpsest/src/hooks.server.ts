import { verifyToken, getToken } from '$lib/server/auth';
import { getDb } from '$lib/server/db';
import { setupDatabase } from '$lib/server/schema';
import { building } from '$app/environment';
import type { Handle } from '@sveltejs/kit';
import { mkdirSync } from 'fs';

let ready = false;

export const handle: Handle = async ({ event, resolve }) => {
  if (!ready) {
    mkdirSync('data', { recursive: true });
    setupDatabase();
    ready = true;
  }

  const token = getToken(event);
  if (token) {
    try {
      const payload = await verifyToken(token);
      const db = getDb();
      const profile = db.prepare('SELECT id, email, display_name, avatar_url FROM profiles WHERE id = ?').get(payload.sub) as any;
      event.locals.user = profile ?? { id: payload.sub, email: payload.email };
    } catch {
      event.cookies.delete('token', { path: '/' });
    }
  }

  return resolve(event);
};
