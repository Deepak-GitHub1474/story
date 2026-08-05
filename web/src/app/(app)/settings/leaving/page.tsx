import type { Metadata } from 'next';
import { LeavingForms } from './LeavingForms';

export const metadata: Metadata = { title: 'Leaving' };

export default function LeavingPage() {
  return <LeavingForms />;
}
