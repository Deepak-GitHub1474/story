import type { Metadata } from 'next';
import { Literata, Public_Sans } from 'next/font/google';
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
  title: { default: 'STORY Admin', template: '%s · STORY Admin' },
  robots: { index: false, follow: false, nocache: true },
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html
      lang="en"
      data-theme="midnight"
      className={`${literata.variable} ${publicSans.variable}`}
    >
      <body
        suppressHydrationWarning
        className="min-h-dvh bg-bg text-text-primary antialiased"
      >
        {children}
      </body>
    </html>
  );
}
