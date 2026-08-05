import type { Metadata } from 'next';
import '@/styles/tokens.css';
import './globals.css';

export const metadata: Metadata = {
  title: { default: 'STORY Admin', template: '%s · STORY Admin' },
  robots: { index: false, follow: false, nocache: true },
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" data-theme="midnight">
      <body className="min-h-dvh bg-bg text-text-primary antialiased">{children}</body>
    </html>
  );
}
