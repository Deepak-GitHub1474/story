import type { Metadata } from 'next';
import { Literata, Public_Sans } from 'next/font/google';
import { ThemeScript } from '@/components/ThemeScript';
import { SITE_NAME, SITE_URL } from '@/lib/config';
import './globals.css';

const literata = Literata({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-literata',
  weight: ['400', '500', '600', '700'],
  style: ['normal', 'italic'],
});

const publicSans = Public_Sans({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-public-sans',
  weight: ['400', '500', '600', '700'],
});

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: `${SITE_NAME} — say the thing you cannot say anywhere else`,
    template: `%s · ${SITE_NAME}`,
  },
  description:
    'Anonymous long-form storytelling. No email, no phone, no real name. ' +
    'Nobody here knows who you are, and that is the point.',
  openGraph: { siteName: SITE_NAME, type: 'website' },
  robots: { index: true, follow: true },
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html
      lang="en"
      suppressHydrationWarning
      className={`${literata.variable} ${publicSans.variable}`}
    >
      <head>
        <ThemeScript />
      </head>
      <body
        suppressHydrationWarning
        className="min-h-dvh bg-bg text-text-primary antialiased"
      >
        {children}
      </body>
    </html>
  );
}
