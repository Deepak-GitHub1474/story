import { NextResponse } from 'next/server';
import { backendFetch } from '@/lib/server/session';

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  const { id } = await params;

  const result = await backendFetch<{ url: string }>(`/vault/items/${id}/download`);
  if (!result.ok) return new NextResponse(null, { status: 404 });

  const upstream = await fetch(result.value.url);
  if (!upstream.ok || !upstream.body) return new NextResponse(null, { status: 502 });

  return new NextResponse(upstream.body, {
    headers: {
      'content-type': 'application/octet-stream',
      'cache-control': 'private, no-store',
    },
  });
}
