import type { Metadata } from 'next';
import Link from 'next/link';
import { Reveal } from '@/components/Reveal';
import { SITE_NAME, SITE_URL } from '@/lib/config';

export const metadata: Metadata = {
  title: `${SITE_NAME} — write it down, stay unknown`,
  description:
    'A place to write the things you cannot put anywhere else, and the good ' +
    'things nobody asks about. No email, no phone, no real name. Encrypted ' +
    'vault. Read by people, not by an algorithm.',
  alternates: { canonical: '/' },
  openGraph: {
    title: `${SITE_NAME} — write it down, stay unknown`,
    description:
      'Anonymous long-form writing. Joy first. Encrypted vault. No email, ' +
      'no phone, no real name.',
    url: SITE_URL,
    type: 'website',
  },
};

const ROOMS = [
  ['Good Day', 'Something went right. Say it here.'],
  ['Laughing Again', 'The funny thing that happened to you.'],
  ['Falling', 'The beginning of something.'],
  ['The Ones Who Show Up', 'Friends who turned up.'],
  ['Finally Happened', 'The thing you waited years for.'],
  ['Still Here', 'Gratitude without performance.'],
];

const PROMISES = [
  [
    'No email, no phone, no real name',
    'Signing up asks for a username and a password. That is the whole form. ' +
      'You cannot leak what was never collected, and we collected nothing.',
  ],
  [
    'A vault only you can open',
    'Files are encrypted on your device before they leave it. Two secrets ' +
      'unlock them and we hold neither, so a full copy of our database is ' +
      'a pile of noise.',
  ],
  [
    'Messages nobody else can read',
    'Direct messages are locked on your phone and unlocked on theirs. The ' +
      'server stores ciphertext and has no way to turn it back into words.',
  ],
  [
    'Read by people, not by a feed machine',
    'What you see comes from who you follow and what you said you care ' +
      'about. Nothing is boosted because it made someone angry.',
  ],
];

const JSON_LD = {
  '@context': 'https://schema.org',
  '@type': 'WebSite',
  name: SITE_NAME,
  url: SITE_URL,
  description:
    'Anonymous long-form writing with an encrypted vault and private ' +
    'messages. No email, no phone, no real name.',
};

export default function HomePage() {
  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(JSON_LD).replace(/</g, '\\u003c') }}
      />

      <div className="min-h-dvh bg-bg text-text-primary">
        <header className="mx-auto flex max-w-6xl items-center justify-between px-5 py-6 sm:px-8">
          <span className="rise text-[length:var(--text-label)] font-medium tracking-[0.4em]">
            STORY
          </span>
          <nav className="rise flex items-center gap-6" style={{ animationDelay: '80ms' }}>
            <Link
              href="/signin"
              className="text-[length:var(--text-label)] text-text-secondary transition-colors hover:text-text-primary"
            >
              Sign in
            </Link>
            <Link
              href="/signup"
              className="inline-flex h-10 items-center rounded-[length:var(--radius-md)] bg-accent px-5 text-[length:var(--text-caption)] font-medium tracking-[var(--tracking-label)] text-accent-text transition-[filter] duration-[var(--motion-fast)] hover:brightness-108"
            >
              Start writing
            </Link>
          </nav>
        </header>

        <main>
          <section className="mx-auto grid max-w-6xl gap-12 px-5 pt-12 pb-[var(--space-section)] sm:px-8 lg:grid-cols-12 lg:gap-10 lg:pt-24">
            <div className="lg:col-span-7">
              <p
                className="rise text-[length:var(--text-caption)] tracking-[var(--tracking-eyebrow)] text-text-muted uppercase"
                style={{ animationDelay: '120ms' }}
              >
                Anonymous · Long form · Encrypted
              </p>

              <h1
                className="rise font-editorial mt-7 text-[length:var(--text-display)] leading-[1.02] font-semibold tracking-[var(--tracking-display)] text-balance"
                style={{ animationDelay: '200ms' }}
              >
                Write it down.
                <br />
                Stay unknown.
              </h1>

              <p
                className="rise mt-8 max-w-xl text-[length:var(--text-body)] leading-[1.75] text-text-secondary"
                style={{ animationDelay: '300ms' }}
              >
                The good day nobody asked about. The thing you have never said out
                loud. Both belong here, and neither one needs your name attached to
                it.
              </p>

              <div
                className="rise mt-10 flex flex-wrap items-center gap-x-7 gap-y-4"
                style={{ animationDelay: '400ms' }}
              >
                <Link
                  href="/signup"
                  className="inline-flex h-13 items-center rounded-[length:var(--radius-md)] bg-accent px-7 text-[length:var(--text-label)] font-medium tracking-[var(--tracking-label)] text-accent-text transition-[filter] duration-[var(--motion-fast)] hover:brightness-108"
                >
                  Create an account
                </Link>
                <span className="max-w-64 text-[length:var(--text-caption)] leading-relaxed text-text-muted">
                  Takes a username and a password. Nothing else.
                </span>
              </div>
            </div>

            <div className="lg:col-span-5 lg:pt-16">
              <figure className="rise relative" style={{ animationDelay: '520ms' }}>
                <span
                  aria-hidden="true"
                  className="font-editorial pointer-events-none absolute -top-16 -left-1 text-[6rem] leading-none text-accent/20 select-none"
                >
                  &ldquo;
                </span>
                <div className="h-px w-14 bg-accent/70" />
                <blockquote className="font-editorial relative mt-7 text-[clamp(1.4rem,2.7vw,1.85rem)] leading-[1.48] text-balance">
                  I told six hundred strangers something I have never told my
                  brother, and then I slept properly for the first time in a year.
                </blockquote>
                <figcaption className="mt-6 text-[length:var(--text-caption)] tracking-[var(--tracking-eyebrow)] text-text-muted uppercase">
                  Written on Story · Author unknown, permanently
                </figcaption>
              </figure>
            </div>
          </section>

          <div className="rule-soft mx-auto h-px max-w-6xl" />

          <section className="mx-auto max-w-6xl px-5 py-[var(--space-section)] sm:px-8">
            <Reveal as="div" className="max-w-2xl">
              <p className="text-[length:var(--text-caption)] tracking-[var(--tracking-eyebrow)] text-text-muted uppercase">
                01 — What lands here
              </p>
              <h2 className="font-editorial mt-6 text-[clamp(1.9rem,1rem+3.4vw,2.9rem)] leading-[1.1] font-semibold tracking-[var(--tracking-title)] text-balance">
                It opens with the good things, on purpose.
              </h2>
              <p className="mt-6 text-[length:var(--text-body)] leading-[1.75] text-text-secondary">
                Most places built for honesty end up being places for grief alone.
                Story opens on Joy, Love, Friendship and Wins, because a room where
                only hard things are allowed stops being honest — it just becomes
                heavy. The hard rooms are here too, further in, waiting quietly for
                the night you need them.
              </p>
            </Reveal>

            <ul className="mt-16 grid gap-x-10 gap-y-12 sm:grid-cols-2 lg:grid-cols-3">
              {ROOMS.map(([name, blurb], index) => (
                <Reveal as="li" key={name} delay={index * 70}>
                  <p className="font-editorial text-[length:var(--text-heading)] font-semibold">
                    {name}
                  </p>
                  <p className="mt-2 leading-relaxed text-text-secondary">{blurb}</p>
                </Reveal>
              ))}
            </ul>
          </section>

          <section className="bg-surface">
            <div className="mx-auto max-w-6xl px-5 py-[var(--space-section)] sm:px-8">
              <Reveal as="div" className="max-w-2xl">
                <p className="text-[length:var(--text-caption)] tracking-[var(--tracking-eyebrow)] text-text-muted uppercase">
                  02 — Why it is safe to say
                </p>
                <h2 className="font-editorial mt-6 text-[clamp(1.9rem,1rem+3.4vw,2.9rem)] leading-[1.1] font-semibold tracking-[var(--tracking-title)] text-balance">
                  Privacy you can check, not privacy you are asked to trust.
                </h2>
              </Reveal>

              <dl className="mt-16 grid gap-x-14 gap-y-14 lg:grid-cols-2">
                {PROMISES.map(([title, body], index) => (
                  <Reveal as="div" key={title} delay={index * 80}>
                    <dt className="flex items-baseline gap-4">
                      <span className="text-[length:var(--text-caption)] text-text-muted tabular-nums">
                        {String(index + 1).padStart(2, '0')}
                      </span>
                      <span className="font-editorial text-[length:var(--text-heading)] font-semibold">
                        {title}
                      </span>
                    </dt>
                    <dd className="mt-3 pl-9 leading-[1.75] text-text-secondary">
                      {body}
                    </dd>
                  </Reveal>
                ))}
              </dl>
            </div>
          </section>

          <section className="mx-auto max-w-6xl px-5 py-[var(--space-section)] sm:px-8">
            <div className="grid gap-14 lg:grid-cols-12 lg:gap-10">
              <Reveal as="div" className="lg:col-span-5">
                <p className="text-[length:var(--text-caption)] tracking-[var(--tracking-eyebrow)] text-text-muted uppercase">
                  03 — The vault
                </p>
                <h2 className="font-editorial mt-6 text-[clamp(1.9rem,1rem+3.4vw,2.9rem)] leading-[1.1] font-semibold tracking-[var(--tracking-title)] text-balance">
                  Some things are not for posting.
                </h2>
              </Reveal>

              <Reveal as="div" delay={120} className="lg:col-span-7 lg:pt-16">
                <p className="max-w-xl text-[length:var(--text-body)] leading-[1.75] text-text-secondary">
                  Photos, video and documents you want kept rather than shown. They
                  are encrypted on your phone before they are uploaded, using a key
                  built from two secrets — your password and a vault passcode. We
                  store neither.
                </p>
                <p className="mt-6 max-w-xl text-[length:var(--text-body)] leading-[1.75] text-text-secondary">
                  That has a consequence we would rather say plainly than bury: if
                  you forget your password, what is in the vault is gone. Not
                  withheld — gone. That is the same property that makes it private
                  in the first place.
                </p>
                <div className="mt-9 flex flex-wrap gap-x-8 gap-y-3 text-[length:var(--text-label)] text-text-muted">
                  <span>AES-256-GCM</span>
                  <span>Argon2id</span>
                  <span>Keys never leave your device</span>
                </div>
              </Reveal>
            </div>
          </section>

          <section className="border-t border-border">
            <div className="mx-auto max-w-6xl px-5 py-[var(--space-section)] sm:px-8">
              <Reveal as="div" className="max-w-3xl">
                <h2 className="font-editorial text-[clamp(2.1rem,1rem+4.4vw,3.5rem)] leading-[1.06] font-semibold tracking-[var(--tracking-display)] text-balance">
                  Nobody here will ever know who you are.
                  <span className="block text-text-muted">That is the point.</span>
                </h2>
                <div className="mt-10 flex flex-wrap items-center gap-x-7 gap-y-4">
                  <Link
                    href="/signup"
                    className="inline-flex h-13 items-center rounded-[length:var(--radius-md)] bg-accent px-7 text-[length:var(--text-label)] font-medium tracking-[var(--tracking-label)] text-accent-text transition-[filter] duration-[var(--motion-fast)] hover:brightness-108"
                  >
                    Create an account
                  </Link>
                  <Link
                    href="/signin"
                    className="text-[length:var(--text-label)] font-medium text-text-secondary underline-offset-4 transition-colors hover:text-text-primary hover:underline"
                  >
                    I already have one
                  </Link>
                </div>
              </Reveal>
            </div>
          </section>
        </main>

        <footer className="border-t border-border">
          <div className="mx-auto flex max-w-6xl flex-col gap-4 px-5 py-10 text-[length:var(--text-caption)] sm:px-8 text-text-muted sm:flex-row sm:items-center sm:justify-between">
            <p>
              Reading a story someone sent you? Open the link — no account needed.
            </p>
            <p className="tracking-[0.28em]">STORY</p>
          </div>
        </footer>
      </div>
    </>
  );
}
