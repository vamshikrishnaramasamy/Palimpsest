import { json } from '@sveltejs/kit';
import { getDb } from '$lib/server/db';

export async function GET({ locals }) {
  const db = getDb();
  const viewer = locals.user;

  const people = viewer
    ? db.prepare(`
      SELECT
        pr.id,
        pr.display_name,
        pr.email,
        COUNT(DISTINCT other.group_id) as crossings,
        COALESCE(MAX(other.created_at), datetime('now')) as last_seen
      FROM posts mine
      INNER JOIN posts other ON other.group_id = mine.group_id AND other.user_id != mine.user_id
      INNER JOIN profiles pr ON pr.id = other.user_id
      WHERE mine.user_id = ?
        AND mine.group_id IS NOT NULL
      GROUP BY pr.id
      ORDER BY crossings DESC, last_seen DESC
      LIMIT 6
    `).all(viewer.id) as any[]
    : db.prepare(`
      SELECT
        pr.id,
        pr.display_name,
        pr.email,
        COUNT(p.id) as crossings,
        COALESCE(MAX(p.created_at), datetime('now')) as last_seen
      FROM profiles pr
      LEFT JOIN posts p ON p.user_id = pr.id
      GROUP BY pr.id
      ORDER BY crossings DESC, pr.display_name ASC
      LIMIT 6
    `).all() as any[];

  const places = viewer
    ? db.prepare(`
      SELECT
        g.name as name,
        COUNT(DISTINCT other.user_id) as count
      FROM posts mine
      INNER JOIN posts other ON other.group_id = mine.group_id AND other.user_id != mine.user_id
      INNER JOIN groups_ g ON g.id = mine.group_id
      WHERE mine.user_id = ?
        AND mine.group_id IS NOT NULL
      GROUP BY g.id
      ORDER BY count DESC, g.name ASC
      LIMIT 8
    `).all(viewer.id) as any[]
    : db.prepare(`
      SELECT
        g.name as name,
        COUNT(p.id) as count
      FROM posts p
      INNER JOIN groups_ g ON g.id = p.group_id
      WHERE p.group_id IS NOT NULL
      GROUP BY g.name
      ORDER BY count DESC
      LIMIT 8
    `).all() as any[];

  const maxCount = Math.max(1, ...places.map((place) => Number(place.count)));
  const uniquePeople = dedupePeopleByName(people);
  const mappedPeople = uniquePeople.map((person, index) => ({
    id: person.id,
    name: person.display_name || person.email?.split('@')[0] || 'Anonymous',
    email: person.email,
    status: index === 0 ? 'consented' : index === 1 ? 'pending' : 'invite',
    crossings: Number(person.crossings),
    places: viewer ? sharedPlacesForPerson(db, viewer.id, person.id) : [],
    last: person.crossings > 0 ? `Last trace ${new Date(person.last_seen).toLocaleDateString()}` : 'Invite required to compare paths'
  }));
  const mappedPlaces = places.map((place) => ({
    name: place.name,
    count: Number(place.count),
    strength: Number(place.count) / maxCount
  }));

  return json({
    featured: mappedPeople[0] ?? null,
    people: mappedPeople,
    places: mappedPlaces,
    totals: {
      people: mappedPeople.length,
      places: mappedPlaces.length,
      crossings: mappedPeople.reduce((sum, person) => sum + person.crossings, 0)
    }
  });
}

function dedupePeopleByName(people: any[]) {
  const byName = new Map<string, any>();
  for (const person of people) {
    const name = person.display_name || person.email?.split('@')[0] || 'Anonymous';
    const existing = byName.get(name);
    if (!existing || Number(person.crossings) > Number(existing.crossings)) {
      byName.set(name, person);
    }
  }
  return Array.from(byName.values());
}

function sharedPlacesForPerson(db: ReturnType<typeof getDb>, viewerId: string, personId: string) {
  return db.prepare(`
    SELECT
      g.name as name,
      COUNT(*) as count
    FROM posts mine
    INNER JOIN posts other ON other.group_id = mine.group_id AND other.user_id = ?
    INNER JOIN groups_ g ON g.id = mine.group_id
    WHERE mine.user_id = ?
      AND mine.group_id IS NOT NULL
    GROUP BY g.id
    ORDER BY count DESC, g.name ASC
    LIMIT 4
  `).all(personId, viewerId).map((place: any) => ({
    name: place.name,
    count: Number(place.count)
  }));
}
