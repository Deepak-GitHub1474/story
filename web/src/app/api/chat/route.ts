import { NextResponse } from 'next/server';
import { backendFetch } from '@/lib/server/session';

export async function GET(request: Request) {
  const params = new URL(request.url).searchParams;
  const conversation = params.get('conversation');

  if (params.get('unread') !== null) {
    const unread = await backendFetch('/chat/unread-count');
    return NextResponse.json(unread.ok ? unread.value : null, {
      status: unread.ok ? 200 : unread.status || 500,
    });
  }

  const path = conversation
    ? `/chat/conversations/${conversation}${buildQuery(params)}`
    : `/chat/conversations${params.get('state') ? '?state=pending' : ''}`;

  const result = await backendFetch(path);
  return NextResponse.json(result.ok ? result.value : null, {
    status: result.ok ? 200 : result.status || 500,
  });
}

function buildQuery(params: URLSearchParams) {
  if (params.get('messages') === null) return '';
  const query = new URLSearchParams({ limit: '30' });
  const after = params.get('after');
  const cursor = params.get('cursor');
  if (after) query.set('after', after);
  if (cursor) query.set('cursor', cursor);
  return `/messages?${query}`;
}
