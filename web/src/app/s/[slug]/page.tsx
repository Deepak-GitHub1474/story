import type { Metadata } from 'next';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { Avatar } from '@/components/Avatar';
import { StoryImages } from '@/components/StoryImages';
import { apiCall } from '@/lib/api';
import { mediaUrl, SITE_NAME } from '@/lib/config';
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
  const images = (story.images ?? []).slice(0, 1).map((path) => mediaUrl(path));

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
      ...(images.length > 0 ? { images } : {}),
    },
    twitter: {
      card: images.length > 0 ? 'summary_large_image' : 'summary',
      title,
      description,
      ...(images.length > 0 ? { images } : {}),
    },
  };
}

export default async function PublicStoryPage({ params }: Props) {
  const { slug } = await params;
  const story = await loadStory(slug);

  if (!story) notFound();

  const title = story.title?.trim();

  return (
    <main className="mx-auto max-w-[42rem] px-5 py-12 sm:px-8 sm:py-20">
      <Link
        href="/"
        className="font-editorial text-[length:var(--text-label)] font-semibold tracking-[0.34em] text-text-muted transition-colors hover:text-text-secondary"
      >
        STORY
      </Link>

      <article className="mt-14">
        {story.community ? (
          <p className="text-[length:var(--text-caption)] tracking-[var(--tracking-eyebrow)] text-text-muted uppercase">
            {story.community.name}
          </p>
        ) : null}

        {title ? (
          <h1 className="font-editorial mt-5 text-[length:var(--text-title)] leading-[1.06] font-semibold tracking-[var(--tracking-title)] text-balance sm:text-[2.85rem]">
            {title}
          </h1>
        ) : null}

        <div className="mt-8 flex items-center gap-3 border-y border-border py-4">
          <Avatar seed={story.author.avatar_seed} size={36} />
          <div className="min-w-0">
            <p className="truncate text-[length:var(--text-label)] font-medium">
              {story.author.display_name}
            </p>
            <p className="truncate text-[length:var(--text-caption)] text-text-muted">
              {[formatDate(story.published_at), `${story.reading_minutes} min read`]
                .filter(Boolean)
                .join(' · ')}
            </p>
          </div>
        </div>

        {story.images && story.images.length > 0 ? (
          <StoryImages
            images={story.images}
            ratio={story.image_ratio}
            fit={story.image_fit}
          />
        ) : null}

        <div className="story-body mt-10 max-w-[var(--size-measure)] text-text-primary/92">
          {paragraphs(story.body).map((paragraph, index) => (
            <p key={index}>{paragraph}</p>
          ))}
        </div>
      </article>

      <aside className="mt-20 border-t border-border pt-10">
        <h2 className="font-editorial text-[length:var(--text-heading)] font-semibold tracking-[var(--tracking-title)]">
          Written anonymously on STORY
        </h2>
        <p className="mt-3 max-w-[52ch] leading-relaxed text-text-secondary">
          The person who wrote this has no name here, no email on file, and no
          profile photo. That is what let them write it.
        </p>
        <Link
          href="/signup"
          className="mt-7 inline-flex h-11 items-center rounded-[length:var(--radius-md)] bg-accent px-6 text-[length:var(--text-label)] font-medium tracking-[var(--tracking-label)] text-accent-text transition-[filter] duration-[var(--motion-fast)] hover:brightness-108"
        >
          Write your own
        </Link>
      </aside>
    </main>
  );
}
