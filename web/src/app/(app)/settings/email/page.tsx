import type { Metadata } from 'next';
import { requireUser } from '@/lib/server/guard';
import { EmailForm } from './EmailForm';

export const metadata: Metadata = { title: 'Recovery email' };

export default async function EmailPage() {
  const user = await requireUser();
  return <EmailForm masked={user.email_masked} verified={user.email_verified} />;
}
