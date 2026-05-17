// Client-side API wrapper
// All calls go to our own SvelteKit server endpoints

async function api(path: string, options?: RequestInit) {
  const isFormData = options?.body instanceof FormData;
  const headers = isFormData
    ? options?.headers
    : { 'Content-Type': 'application/json', ...options?.headers };

  const res = await fetch(path, {
    ...options,
    headers
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error((body as any).error || res.statusText);
  }
  return res.json();
}

export type Post = {
  id: string;
  user_id: string;
  body: string;
  image_url: string | null;
  like_count: number;
  comment_count: number;
  is_liked: boolean;
  author: {
    id: string;
    email: string;
    display_name: string;
    avatar_url: string | null;
  };
  created_at: string;
};

export type Comment = {
  id: string;
  post_id: string;
  user_id: string;
  body: string;
  author: {
    id: string;
    email: string;
    display_name: string;
    avatar_url: string | null;
  };
  created_at: string;
};

export type Profile = {
  id: string;
  email: string;
  display_name: string;
  avatar_url: string | null;
  created_at: string;
};

export type User = {
  id: string;
  email: string;
  display_name: string;
  avatar_url: string | null;
};

export const client = {
  auth: {
    signUp: (email: string, password: string, display_name?: string) => {
      const body: Record<string, string> = { email, password };
      if (display_name) body.display_name = display_name;
      return api('/api/auth/signup', { method: 'POST', body: JSON.stringify(body) });
    },
    signIn: (email: string, password: string) =>
      api('/api/auth/signin', { method: 'POST', body: JSON.stringify({ email, password }) }),
    signOut: () =>
      api('/api/auth/signout', { method: 'POST' }),
    me: () =>
      api('/api/auth/me')
  },

  posts: {
    list: (params?: { tab?: 'for_you' | 'following'; limit?: number; before?: string }) => {
      const query = new URLSearchParams();
      if (params?.tab) query.set('tab', params.tab);
      if (params?.limit) query.set('limit', String(params.limit));
      if (params?.before) query.set('before', params.before);
      const qs = query.toString();
      return api(`/api/posts${qs ? `?${qs}` : ''}`);
    },
    create: (form: FormData) =>
      api('/api/posts', { method: 'POST', body: form, headers: {} }),
    like: (id: string) =>
      api(`/api/posts/${id}/like`, { method: 'POST' }),
    comments: {
      list: (postId: string) =>
        api(`/api/posts/${postId}/comments`),
      create: (postId: string, body: string) =>
        api(`/api/posts/${postId}/comments`, { method: 'POST', body: JSON.stringify({ body }) })
    }
  },

  profile: {
    get: () =>
      api('/api/profile'),
    update: (form: FormData) =>
      api('/api/profile', { method: 'POST', body: form, headers: {} })
  },

  overlap: {
    summary: () =>
      api('/api/overlap')
  },

  users: {
    search: (query: string) =>
      api(`/api/users/search?q=${encodeURIComponent(query)}`)
  }
};
