import type { Metadata } from 'next';
import { Archivo, Spline_Sans_Mono } from 'next/font/google';
import './globals.css';

const archivo = Archivo({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-archivo',
  weight: ['400', '500', '600', '700'],
});

const splineMono = Spline_Sans_Mono({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-spline-mono',
  weight: ['400', '500', '600'],
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
      className={`${archivo.variable} ${splineMono.variable}`}
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
