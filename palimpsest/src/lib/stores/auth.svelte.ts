import { client } from '$lib/api';

export const authState = $state<{
  user: { id: string; email: string } | null;
  loading: boolean;
  error: string | null;
}>({
  user: null,
  loading: true,
  error: null
});

export function initAuth() {
  client.auth.me()
    .then((data) => {
      authState.user = data.user;
      authState.loading = false;
    })
    .catch(() => {
      authState.loading = false;
    });
}

export async function signUp(email: string, password: string) {
  authState.error = null;
  try {
    const displayName = email.split('@')[0];
    const data = await client.auth.signUp(email, password, displayName);
    authState.user = data.user;
    return true;
  } catch (e: any) {
    authState.error = e.message;
    return false;
  }
}

export async function signIn(email: string, password: string) {
  authState.error = null;
  try {
    const data = await client.auth.signIn(email, password);
    authState.user = data.user;
    return true;
  } catch (e: any) {
    authState.error = e.message;
    return false;
  }
}

export async function signOut() {
  await client.auth.signOut();
  authState.user = null;
}
