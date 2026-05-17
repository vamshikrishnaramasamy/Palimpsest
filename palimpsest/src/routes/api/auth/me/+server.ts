import { json } from '@sveltejs/kit';

export function GET({ locals }) {
  if (!locals.user) {
    return json({ user: null });
  }
  return json({ user: locals.user });
}
