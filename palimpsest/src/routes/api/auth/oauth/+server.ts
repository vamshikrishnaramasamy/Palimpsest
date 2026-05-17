import { json } from '@sveltejs/kit';
import { createRemoteJWKSet, jwtVerify } from 'jose';
import { randomUUID } from 'crypto';
import { getDb } from '$lib/server/db';
import { createToken } from '$lib/server/auth';

const appleJWKS = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));
const googleJWKS = createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs'));

type Provider = 'apple' | 'google';

type OAuthIdentity = {
  provider: Provider;
  subject: string;
  email: string | null;
  displayName: string | null;
};

export async function POST({ request, cookies }) {
  const { provider, id_token, display_name } = await request.json();

  if ((provider !== 'apple' && provider !== 'google') || !id_token) {
    return json({ error: 'Provider and identity token are required' }, { status: 400 });
  }

  try {
    const identity = provider === 'apple'
      ? await verifyAppleToken(id_token, display_name)
      : await verifyGoogleToken(id_token, display_name);

    const db = getDb();
    const linked = db.prepare(`
      SELECT p.id, p.email, p.display_name, p.avatar_url
      FROM social_accounts sa
      JOIN profiles p ON p.id = sa.user_id
      WHERE sa.provider = ? AND sa.provider_subject = ?
    `).get(identity.provider, identity.subject) as any;

    let user = linked;

    if (!user && identity.email) {
      user = db.prepare('SELECT id, email, display_name, avatar_url FROM profiles WHERE email = ?').get(identity.email) as any;
    }

    if (!user) {
      const id = randomUUID();
      const email = identity.email ?? `${identity.provider}-${identity.subject}@auth.palimpsest.local`;
      const displayName = identity.displayName ?? displayNameFromEmail(email);
      db.prepare('INSERT INTO profiles (id, email, password_hash, display_name) VALUES (?, ?, ?, ?)')
        .run(id, email, `oauth:${identity.provider}:${identity.subject}`, displayName);
      user = { id, email, display_name: displayName, avatar_url: null };
    }

    db.prepare(`
      INSERT OR IGNORE INTO social_accounts (provider, provider_subject, user_id, email)
      VALUES (?, ?, ?, ?)
    `).run(identity.provider, identity.subject, user.id, identity.email);

    if (identity.displayName && !user.display_name) {
      db.prepare('UPDATE profiles SET display_name = ? WHERE id = ?').run(identity.displayName, user.id);
      user.display_name = identity.displayName;
    }

    const token = await createToken(user.id, user.email);
    cookies.set('token', token, {
      path: '/',
      httpOnly: true,
      sameSite: 'lax',
      maxAge: 60 * 60 * 24 * 7
    });

    return json({ user, token });
  } catch (error) {
    const message = error instanceof Error ? error.message : 'OAuth sign-in failed';
    return json({ error: message }, { status: 401 });
  }
}

async function verifyAppleToken(idToken: string, displayName?: string): Promise<OAuthIdentity> {
  const audience = (process.env.APPLE_BUNDLE_ID || 'com.vamshikrishnaramasamy.overlap.dev,dev.palimpsest.social')
    .split(',')
    .map((value) => value.trim())
    .filter(Boolean);
  const { payload } = await jwtVerify(idToken, appleJWKS, {
    issuer: 'https://appleid.apple.com',
    audience
  });

  if (!payload.sub) throw new Error('Apple token is missing a subject');

  return {
    provider: 'apple',
    subject: payload.sub,
    email: typeof payload.email === 'string' ? payload.email : null,
    displayName: cleanDisplayName(displayName)
  };
}

async function verifyGoogleToken(idToken: string, displayName?: string): Promise<OAuthIdentity> {
  const audience = process.env.GOOGLE_IOS_CLIENT_ID;
  if (!audience) {
    throw new Error('Google sign-in is not configured on the server yet.');
  }

  const { payload } = await jwtVerify(idToken, googleJWKS, {
    audience
  });

  const issuer = String(payload.iss ?? '');
  if (issuer !== 'accounts.google.com' && issuer !== 'https://accounts.google.com') {
    throw new Error('Google token has an invalid issuer');
  }
  if (!payload.sub) throw new Error('Google token is missing a subject');

  return {
    provider: 'google',
    subject: payload.sub,
    email: typeof payload.email === 'string' ? payload.email : null,
    displayName: cleanDisplayName(displayName) ?? (typeof payload.name === 'string' ? payload.name : null)
  };
}

function cleanDisplayName(name: unknown): string | null {
  if (typeof name !== 'string') return null;
  const cleaned = name.replace(/\s+/g, ' ').trim();
  return cleaned || null;
}

function displayNameFromEmail(email: string): string {
  return email
    .split('@')[0]
    .replace(/[._-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/\b\w/g, (char) => char.toUpperCase()) || 'New Visitor';
}
