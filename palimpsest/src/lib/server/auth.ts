import { SignJWT, jwtVerify } from 'jose';
import type { RequestEvent } from '@sveltejs/kit';

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-me-in-production';
const secret = new TextEncoder().encode(JWT_SECRET);

export async function createToken(userId: string, email: string): Promise<string> {
  return new SignJWT({ sub: userId, email })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime('7d')
    .sign(secret);
}

export async function verifyToken(token: string) {
  const { payload } = await jwtVerify(token, secret);
  return payload as { sub: string; email: string };
}

export function getToken(event: RequestEvent): string | null {
  // Check cookie first, then fall back to Authorization header (for iOS/mobile)
  const cookieToken = event.cookies.get('token') ?? null;
  if (cookieToken) return cookieToken;

  const authHeader = event.request.headers.get('authorization');
  if (authHeader?.startsWith('Bearer ')) {
    return authHeader.slice(7);
  }
  return null;
}
