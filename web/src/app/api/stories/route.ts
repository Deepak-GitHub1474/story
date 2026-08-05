import { NextResponse } from 'next/server';
import { backendFetch } from '@/lib/server/session';
import type { TPage, TStory } from '@/lib/types';

const SOURCES: Record<string, (params: URLSearchParams) => string> = {
  feed: () => '/stories/feed',
  mine: () => '/stories/mine',
  community: (params) => `/communities/${params.get('slug')}/stories`,
  user: (params) => `/users/${params.get('username')}/stories`,
};

export async function GET(request: Request) {
  const params = new URL(request.url).searchParams;
  const build = SOURCES[params.get('source') ?? 'feed'];
  if (!build) return NextResponse.json(null, { status: 400 });

  const query = new URLSearchParams({ limit: '20' });
  const cursor = params.get('cursor');
  const visibility = params.get('visibility');
  if (cursor) query.set('cursor', cursor);
  if (visibility) query.set('visibility', visibility);

  const result = await backendFetch<TPage<TStory>>(`${build(params)}?${query}`);

  return NextResponse.json(result.ok ? result.value : null, {
    status: result.ok ? 200 : result.status || 500,
  });
}
