import { NextResponse } from 'next/server';
import { backendFetch } from '@/lib/server/session';

const KINDS = new Set(['image/jpeg', 'image/png']);

export async function POST(request: Request) {
  const body = (await request.json().catch(() => null)) as {
    kind?: string;
    data?: string;
  } | null;

  if (!body?.data || !body.kind || !KINDS.has(body.kind)) {
    return NextResponse.json(
      { message: 'Pictures have to be a JPEG or a PNG.' },
      { status: 400 },
    );
  }

  const result = await backendFetch<{ media_id: string; url: string }>(
    '/media/images',
    { method: 'POST', body: { kind: body.kind, data: body.data } },
  );

  return NextResponse.json(
    result.ok ? result.value : { message: result.message },
    { status: result.ok ? 201 : result.status || 500 },
  );
}
