<script lang="ts">
  import { goto } from '$app/navigation';
  import { client } from '$lib/api';

  interface Post {
    id: string;
    user_id: string;
    display_name: string | null;
    email: string;
    body: string | null;
    image_url: string | null;
    created_at: string;
    like_count: number;
    comment_count: number;
    liked_by_me: boolean;
  }

  let { post }: { post: Post } = $props();

  let liked = $state(false);
  let likeCount = $state(0);

  $effect(() => {
    liked = post.liked_by_me;
    likeCount = post.like_count;
  });

  function getDisplayName() {
    return post.display_name || post.email?.split('@')[0] || 'Anonymous';
  }
  function getAvatarLetter() {
    return getDisplayName()[0]?.toUpperCase() || '?';
  }

  async function toggleLike() {
    // Optimistic update
    liked = !liked;
    likeCount += liked ? 1 : -1;

    try {
      const result: { liked: boolean } = await client.posts.like(post.id);
      if (!result.liked) {
        liked = false;
        likeCount = Math.max(0, likeCount - 1);
      }
    } catch {
      // Revert on failure
      liked = !liked;
      likeCount += liked ? -1 : 1;
    }
  }

  function goToComments() {
    goto('/post/' + post.id);
  }

  function timeAgo(dateStr: string): string {
    const now = Date.now();
    const date = new Date(dateStr).getTime();
    const diffMs = now - date;
    if (diffMs < 0) return 'just now';
    const diffMin = Math.floor(diffMs / 60000);
    if (diffMin < 1) return 'just now';
    if (diffMin < 60) return `${diffMin} min ago`;
    const diffHr = Math.floor(diffMin / 60);
    if (diffHr < 24) return `${diffHr} hrs ago`;
    const diffDay = Math.floor(diffHr / 24);
    if (diffDay < 7) return `${diffDay} day${diffDay > 1 ? 's' : ''} ago`;
    const diffWeek = Math.floor(diffDay / 7);
    if (diffWeek < 4) return `${diffWeek}w ago`;
    return new Date(dateStr).toLocaleDateString();
  }
</script>

<div class="px-4 py-4 border-b border-[var(--color-border-light)]">
  <!-- Header row: Avatar + Name/Group + Time + More -->
  <div class="flex items-start gap-3">
    <!-- Avatar circle -->
    <div class="w-[32px] h-[32px] rounded-full bg-[var(--color-surface-muted)] flex items-center justify-center text-sm font-semibold text-[var(--color-text)] shrink-0 border border-[var(--color-border)]">
      {getAvatarLetter()}
    </div>

    <!-- Name, group, and timestamp -->
    <div class="flex-1 min-w-0">
      <div class="flex items-center justify-between gap-2">
        <div class="flex items-center gap-1 min-w-0">
          <span class="text-sm font-semibold text-[var(--color-text)] truncate">{getDisplayName()}</span>
          <span class="text-sm text-[var(--color-text)]">in Group Name</span>
        </div>
        <!-- More button (three dots) -->
        <button class="text-[var(--color-text)] shrink-0 p-1" aria-label="More options">
          <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
            <circle cx="5" cy="12" r="1.5"/>
            <circle cx="12" cy="12" r="1.5"/>
            <circle cx="19" cy="12" r="1.5"/>
          </svg>
        </button>
      </div>
      <p class="text-xs text-[var(--color-text-muted)] mt-0.5">{timeAgo(post.created_at)}</p>
    </div>
  </div>

  <!-- Image (Figma shows images prominently in feed) -->
  {#if post.image_url}
    <img
      src={post.image_url}
      alt=""
      class="w-full rounded mt-3 object-cover max-h-[400px]"
      loading="lazy"
    />
  {/if}

  <!-- Body text -->
  {#if post.body}
    <p class="text-sm text-[var(--color-text)] mt-3 leading-relaxed">{post.body}</p>
  {/if}

  <!-- Actions row: heart icon + likes, chat icon + comments -->
  <div class="flex items-center gap-4 mt-3">
    <button onclick={toggleLike} class="flex items-center gap-2 group">
      {#if liked}
        <svg class="w-5 h-5 text-red-500" viewBox="0 0 24 24" fill="currentColor">
          <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/>
        </svg>
      {:else}
        <svg class="w-5 h-5 text-[var(--color-text)] group-hover:text-red-400 transition-colors" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"/>
        </svg>
      {/if}
      <span class="text-sm font-medium text-[var(--color-text)]">{likeCount} likes</span>
    </button>

    <button onclick={goToComments} class="flex items-center gap-2 group">
      <svg class="w-5 h-5 text-[var(--color-text)] group-hover:text-[var(--color-text-muted)] transition-colors" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
        <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
      </svg>
      <span class="text-sm font-medium text-[var(--color-text)]">{post.comment_count} comments</span>
    </button>
  </div>
</div>
