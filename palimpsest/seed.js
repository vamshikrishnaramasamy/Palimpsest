import Database from 'better-sqlite3';
import bcrypt from 'bcryptjs';
import { randomUUID } from 'crypto';
import { mkdirSync } from 'fs';

const dbPath = process.env.DB_PATH || 'data/palimpsest.db';
const userCount = Number(process.env.SEED_USERS || 1200);
const locationCount = Number(process.env.SEED_LOCATIONS || 1200);
const postCount = Number(process.env.SEED_POSTS || 2400);
const password = process.env.SEED_PASSWORD || 'password123';

mkdirSync('data', { recursive: true });

const db = new Database(dbPath);
const hash = bcrypt.hashSync(password, 10);

const firstNames = [
  'Maya', 'Alex', 'Jules', 'Sam', 'Nina', 'Leo', 'Tessa', 'Iris', 'Noah', 'Ari',
  'Lena', 'Kai', 'Rhea', 'Theo', 'Mina', 'Owen', 'Zara', 'Eli', 'June', 'Sage'
];
const lastNames = [
  'Chen', 'Rivera', 'Kim', 'Patel', 'Brooks', 'Martin', 'Hall', 'Singh', 'Nguyen', 'Carter',
  'Lopez', 'Shah', 'Wong', 'Foster', 'Reed', 'Park', 'Bennett', 'Stone', 'Diaz', 'Lin'
];
const locationRoots = [
  'Library Window', 'Coffee Counter', 'Campus Bench', 'Crosswalk', 'Bookstore Corner',
  'Train Platform', 'Rooftop Garden', 'Stairwell Landing', 'Courtyard Tree', 'Lecture Hall',
  'Quiet Alley', 'Bus Stop', 'Museum Steps', 'Dining Patio', 'Study Room',
  'Bike Rack', 'Fountain Edge', 'Parking Lot', 'Dorm Lobby', 'Theater Door'
];
const storyTemplates = [
  'I stood here longer than I meant to, trying to decide what kind of person I wanted to become.',
  'Someone laughed nearby and it changed the whole texture of this place.',
  'This spot felt ordinary until I realized I would remember it for years.',
  'I passed through here every week before I knew who else was passing through too.',
  'A stranger gave me directions here and accidentally saved my afternoon.',
  'This was the last quiet minute before everything got loud.',
  'I came back here because I wanted proof that places remember us.',
  'Two paths almost crossed here. I think about that more than I should.',
  'The air felt different here, like the city was holding its breath.',
  'I left a secret here because I could not carry it all the way home.',
  'This is where I heard the song that still follows me around.',
  'Nothing dramatic happened here. That is why I trust the memory.'
];
const imagePool = [
  null,
  'https://images.unsplash.com/photo-1494526585095-c41746248156?auto=format&fit=crop&w=900&q=80',
  'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=900&q=80',
  'https://images.unsplash.com/photo-1497366754035-f200968a6e72?auto=format&fit=crop&w=900&q=80',
  'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?auto=format&fit=crop&w=900&q=80'
];

function pad(value, width = 4) {
  return String(value).padStart(width, '0');
}

function pick(list, index) {
  return list[index % list.length];
}

function dateOffset(index, unit = 'minutes') {
  return `-${index + 1} ${unit}`;
}

db.pragma('foreign_keys = OFF');
for (const table of ['comments', 'likes', 'follows', 'posts', 'profiles', 'groups_']) {
  db.exec(`DROP TABLE IF EXISTS ${table};`);
}
db.pragma('foreign_keys = ON');

db.exec(`
  CREATE TABLE profiles (
    id TEXT PRIMARY KEY,
    email TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    created_at TEXT DEFAULT (datetime('now'))
  );

  CREATE TABLE groups_ (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now'))
  );

  CREATE TABLE posts (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    group_id TEXT REFERENCES groups_(id),
    body TEXT,
    image_url TEXT,
    lng REAL,
    lat REAL,
    created_at TEXT DEFAULT (datetime('now'))
  );

  CREATE INDEX posts_user_idx ON posts(user_id);
  CREATE INDEX posts_created_idx ON posts(created_at);
  CREATE INDEX posts_group_idx ON posts(group_id);

  CREATE TABLE comments (
    id TEXT PRIMARY KEY,
    post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    body TEXT NOT NULL,
    created_at TEXT DEFAULT (datetime('now'))
  );

  CREATE INDEX comments_post_idx ON comments(post_id);

  CREATE TABLE likes (
    user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    post_id TEXT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    created_at TEXT DEFAULT (datetime('now')),
    PRIMARY KEY (user_id, post_id)
  );

  CREATE TABLE follows (
    follower_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    following_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at TEXT DEFAULT (datetime('now')),
    PRIMARY KEY (follower_id, following_id)
  );
`);

const insertUser = db.prepare('INSERT INTO profiles (id, email, password_hash, display_name, avatar_url, created_at) VALUES (?, ?, ?, ?, ?, datetime(\'now\', ?))');
const insertGroup = db.prepare('INSERT INTO groups_ (id, name, created_at) VALUES (?, ?, datetime(\'now\', ?))');
const insertPost = db.prepare('INSERT INTO posts (id, user_id, group_id, body, image_url, lng, lat, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, datetime(\'now\', ?))');
const insertComment = db.prepare('INSERT INTO comments (id, post_id, user_id, body, created_at) VALUES (?, ?, ?, ?, datetime(\'now\', ?))');
const insertLike = db.prepare('INSERT OR IGNORE INTO likes (user_id, post_id, created_at) VALUES (?, ?, datetime(\'now\', ?))');
const insertFollow = db.prepare('INSERT OR IGNORE INTO follows (follower_id, following_id, created_at) VALUES (?, ?, datetime(\'now\', ?))');

const users = [];
const locations = [];
const posts = [];

const seed = db.transaction(() => {
  for (let i = 0; i < userCount; i += 1) {
    const first = pick(firstNames, i);
    const last = pick(lastNames, Math.floor(i / firstNames.length) + i);
    const id = randomUUID();
    const email = `${first.toLowerCase()}.${last.toLowerCase()}.${pad(i)}@overlap.app`;
    const displayName = `${first} ${last}`;
    users.push({ id, email, displayName });
    insertUser.run(
      id,
      email,
      hash,
      displayName,
      `https://i.pravatar.cc/150?u=${encodeURIComponent(email)}`,
      dateOffset(i, 'hours')
    );
  }

  for (let i = 0; i < locationCount; i += 1) {
    const id = `place-${pad(i)}`;
    const name = `${pick(locationRoots, i)} ${pad(i)}`;
    const baseLat = 32.8801;
    const baseLng = -117.2376;
    const lat = baseLat + ((i % 40) - 20) * 0.0012;
    const lng = baseLng + (Math.floor(i / 40) - 15) * 0.0012;
    locations.push({ id, name, lat, lng });
    insertGroup.run(id, name, dateOffset(i, 'days'));
  }

  for (let i = 0; i < postCount; i += 1) {
    const user = users[i % users.length];
    const location = locations[i % locations.length];
    const body = `[${location.name}] ${pick(storyTemplates, i)} Trace #${pad(i, 5)}.`;
    const post = {
      id: randomUUID(),
      userId: user.id,
      locationId: location.id
    };
    posts.push(post);
    insertPost.run(
      post.id,
      post.userId,
      post.locationId,
      body,
      imagePool[i % imagePool.length],
      location.lng + ((i % 7) - 3) * 0.00008,
      location.lat + ((i % 9) - 4) * 0.00008,
      dateOffset(i * 7, 'minutes')
    );
  }

  for (let i = 0; i < users.length; i += 1) {
    for (let step = 1; step <= 8; step += 1) {
      const target = users[(i + step * 13) % users.length];
      if (target.id !== users[i].id) insertFollow.run(users[i].id, target.id, dateOffset(i + step, 'days'));
    }
  }

  for (let i = 0; i < posts.length; i += 1) {
    for (let step = 0; step < 6; step += 1) {
      const liker = users[(i * 7 + step * 19) % users.length];
      insertLike.run(liker.id, posts[i].id, dateOffset(i + step, 'hours'));
    }

    for (let step = 0; step < 3; step += 1) {
      const commenter = users[(i * 11 + step * 23) % users.length];
      insertComment.run(
        randomUUID(),
        posts[i].id,
        commenter.id,
        pick([
          'I unlocked this while standing nearby. It made the place feel different.',
          'This layer made me notice something I usually walk past.',
          'I think I crossed this path too, just on another day.',
          'Leaving a reply here because the memory stuck with me.'
        ], i + step),
        dateOffset(i + step * 3, 'minutes')
      );
    }
  }
});

seed();

for (const table of ['profiles', 'groups_', 'posts', 'comments', 'likes', 'follows']) {
  const { c } = db.prepare(`SELECT COUNT(*) as c FROM ${table}`).get();
  console.log(`${table}: ${c}`);
}

console.log(`Demo login: ${users[0].email} / ${password}`);
