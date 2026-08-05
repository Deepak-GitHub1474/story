import type { Metadata } from 'next';
import { requireUser } from '@/lib/server/guard';
import { EditProfileForm } from './EditProfileForm';

export const metadata: Metadata = { title: 'Edit profile' };

export default async function EditProfilePage() {
  const user = await requireUser();
  return <EditProfileForm displayName={user.display_name} bio={user.bio ?? ''} />;
}
