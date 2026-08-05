import type { Metadata } from 'next';
import { redirectIfSignedIn } from '@/lib/server/guard';
import { SignInForm } from './SignInForm';

export const metadata: Metadata = { title: 'Sign in' };

export default async function SignInPage() {
  await redirectIfSignedIn();
  return <SignInForm />;
}
