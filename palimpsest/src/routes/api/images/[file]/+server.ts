import { error } from '@sveltejs/kit';
import { readFileSync } from 'fs';

export function GET({ params }) {
  const file = params.file;
  if (!file || file.includes('..')) throw error(404);
  try {
    const data = readFileSync(`data/images/${file}`);
    const ext = file.split('.').pop() || 'jpg';
    const mime = {
      jpg: 'image/jpeg',
      jpeg: 'image/jpeg',
      png: 'image/png',
      gif: 'image/gif',
      webp: 'image/webp',
      heic: 'image/heic',
      mp4: 'video/mp4',
      m4v: 'video/x-m4v',
      mov: 'video/quicktime',
      webm: 'video/webm',
      mp3: 'audio/mpeg',
      m4a: 'audio/mp4',
      aac: 'audio/aac',
      wav: 'audio/wav',
      caf: 'audio/x-caf',
      ogg: 'audio/ogg'
    }[ext] || 'application/octet-stream';
    return new Response(data, { headers: { 'Content-Type': mime, 'Cache-Control': 'public, max-age=3600' } });
  } catch {
    throw error(404);
  }
}
