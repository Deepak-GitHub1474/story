import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Avatar } from '@/components/Avatar';
import { apiCall } from '@/lib/api';
import { SITE_NAME } from '@/lib/config';
import { formatDate, paragraphs } from '@/lib/format';
import type { TPublicStory } from '@/lib/types';

type Props = { params: Promise<{ slug: string }> };

const REVALIDATE_SECONDS = 60;

async function loadStory(slug: string): Promise<TPublicStory | null> {
  const result = await apiCall<{ story: TPublicStory }>(
    `/public/stories/${encodeURIComponent(slug)}`,
    { revalidate: REVALIDATE_SECONDS },
  );
  return result.ok ? result.value.story : null;
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { slug } = await params;
  const story = await loadStory(slug);

  if (!story) {
    return { title: 'Story not found', robots: { index: false, follow: false } };
  }

  const title = story.title?.trim() || `A story by ${story.author.display_name}`;
  const description = story.excerpt;

  return {
    title,
    description,
    alternates: { canonical: `/s/${story.slug}` },
    openGraph: {
      title,
      description,
      type: 'article',
      siteName: SITE_NAME,
      publishedTime: story.published_at ?? undefined,
      url: `/s/${story.slug}`,
    },
    twitter: { card: 'summary_large_image', title, description },
  };
}

export default async function PublicStoryPage({ params }: Props) {
  const { slug } = await params;
  const story = await loadStory(slug);

  if (!story) notFound();

  const title = story.title?.trim();

  return (
    <main className="mx-auto max-w-2xl px-6 py-12 sm:py-20">
      <Link
        href="/"
        className="text-xs font-semibold tracking-[0.4em] text-text-muted transition-colors hover:text-text-secondary"
      >
        STORY
      </Link>

      <article className="mt-10">
        {title ? (
          <h1 className="text-3xl leading-tight font-bold text-balance sm:text-4xl">
            {title}
          </h1>
        ) : null}

        <div className="mt-6 flex items-center gap-3">
          <Avatar seed={story.author.avatar_seed} size={40} />
          <div className="text-sm">
            <p className="font-semibold">{story.author.display_name}</p>
            <p className="text-text-muted">
              {[
                formatDate(story.published_at),
                `${story.reading_minutes} min read`,
                story.community?.name,
              ]
                .filter(Boolean)
                .join(' · ')}
            </p>
          </div>
        </div>

        <div className="mt-10 space-y-6 text-[1.0625rem] leading-[1.75] text-text-secondary">
          {paragraphs(story.body).map((paragraph, index) => (
            <p key={index}>{paragraph}</p>
          ))}
        </div>
      </article>

      <aside className="mt-16 rounded-xl border border-border bg-surface p-6">
        <h2 className="font-semibold">Written anonymously on STORY</h2>
        <p className="mt-2 text-sm leading-relaxed text-text-secondary">
          The person who wrote this has no name here, no email on file, and no
          profile photo. That is what let them write it.
        </p>
        <Link
          href="/signup"
          className="mt-5 inline-block rounded-lg bg-accent px-5 py-2.5 text-sm font-semibold text-accent-text transition-opacity hover:opacity-90"
        >
          Write your own
        </Link>
      </aside>
    </main>
  );
}
