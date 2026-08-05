import type { Metadata } from 'next';
import { ThemeScript } from '@/components/ThemeScript';
import { SITE_NAME, SITE_URL } from '@/lib/config';
import '@/styles/tokens.css';
import './globals.css';

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
    <html lang="en" suppressHydrationWarning>
      <head>
        <ThemeScript />
      </head>
      <body className="min-h-dvh bg-bg text-text-primary antialiased">{children}</body>
    </html>
  );
}
