const Database = require('better-sqlite3');
const { randomUUID } = require('crypto');

const db = new Database('data/palimpsest.db');
const viewer = db
  .prepare(
    "SELECT id,email,display_name FROM profiles WHERE lower(email) = 'vamshikrishnaramasamy@gmail.com' OR lower(display_name) LIKE '%vamshi%' ORDER BY created_at DESC LIMIT 1"
  )
  .get();

if (!viewer) {
  throw new Error('viewer account not found');
}

const places = db.prepare('SELECT id,name FROM groups_ ORDER BY id LIMIT 14').all();
const people = db
  .prepare("SELECT id,email,display_name FROM profiles WHERE id != ? AND email LIKE '%@overlap.app' ORDER BY display_name LIMIT 8")
  .all(viewer.id);
const getPlaceCoord = db.prepare('SELECT lat,lng FROM posts WHERE group_id = ? AND lat IS NOT NULL AND lng IS NOT NULL LIMIT 1');
const insertPost = db.prepare(
  "INSERT INTO posts (id,user_id,group_id,body,image_url,lng,lat,created_at) VALUES (?,?,?,?,?,?,?,datetime('now', ?))"
);

const existing = db
  .prepare("SELECT COUNT(*) AS c FROM posts WHERE user_id = ? AND body LIKE '[Overlap seed]%'")
  .get(viewer.id).c;

if (existing === 0) {
  const tx = db.transaction(() => {
    places.forEach((place, index) => {
      const coord = getPlaceCoord.get(place.id) || {
        lat: 32.8801 + index * 0.00035,
        lng: -117.2376 + index * 0.00035
      };

      insertPost.run(
        randomUUID(),
        viewer.id,
        place.id,
        `[Overlap seed] You crossed paths near ${place.name}. Your trace was close enough to reveal a shared history.`,
        null,
        coord.lng + 0.00002,
        coord.lat + 0.00002,
        `-${index + 1} hours`
      );

      people.slice(0, 5 + (index % 4)).forEach((person, personIndex) => {
        insertPost.run(
          randomUUID(),
          person.id,
          place.id,
          `[Overlap seed] ${person.display_name} left a trace near ${place.name} before you met.`,
          null,
          coord.lng - 0.00002 - personIndex * 0.000005,
          coord.lat - 0.00002 + personIndex * 0.000005,
          `-${index + personIndex + 2} hours`
        );
      });
    });
  });

  tx();
}

const peopleSummary = db
  .prepare(
    `
    SELECT pr.display_name, pr.email, COUNT(DISTINCT other.group_id) AS crossings
    FROM posts mine
    JOIN posts other ON other.group_id = mine.group_id AND other.user_id != mine.user_id
    JOIN profiles pr ON pr.id = other.user_id
    WHERE mine.user_id = ? AND mine.group_id IS NOT NULL
    GROUP BY pr.id
    ORDER BY crossings DESC
    LIMIT 8
  `
  )
  .all(viewer.id);

const placeSummary = db
  .prepare(
    `
    SELECT g.name, COUNT(DISTINCT other.user_id) AS people
    FROM posts mine
    JOIN posts other ON other.group_id = mine.group_id AND other.user_id != mine.user_id
    JOIN groups_ g ON g.id = mine.group_id
    WHERE mine.user_id = ? AND mine.group_id IS NOT NULL
    GROUP BY g.id
    ORDER BY people DESC, g.name ASC
    LIMIT 8
  `
  )
  .all(viewer.id);

console.log(
  JSON.stringify(
    {
      viewer,
      insertedNow: existing === 0,
      seededViewerPostsAlready: existing,
      people: peopleSummary,
      places: placeSummary
    },
    null,
    2
  )
);
