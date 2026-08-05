import type { Metadata } from 'next';
import { redirectIfSignedIn } from '@/lib/server/guard';
import { SignUpForm } from './SignUpForm';

export const metadata: Metadata = { title: 'Create an account' };

export default async function SignUpPage() {
  await redirectIfSignedIn();
  return <SignUpForm />;
}
