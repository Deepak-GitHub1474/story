import type { Metadata } from 'next';
import { NotificationToggle } from '@/components/NotificationToggle';
import { SignOutButton } from '@/components/SignOutButton';
import { Row, Section } from '@/components/ui/Surface';
import { requireUser } from '@/lib/server/guard';

export const metadata: Metadata = { title: 'Settings' };

export default async function SettingsPage() {
  const user = await requireUser();

  return (
    <div className="mx-auto max-w-2xl space-y-8">
      <h1 className="text-[length:var(--text-title)] font-semibold">Settings</h1>

      <Section title="Account">
        <Row label="Edit profile" href="/settings/profile" />
        <Row label="Your interests" href="/settings/interests" />
        <Row
          label="Recovery email"
          value={user.email_masked ?? 'Not set'}
          href="/settings/email"
        />
        <Row label="Change password" href="/settings/password" />
        <Row label="Active sessions" href="/settings/sessions" />
        <Row label="Blocked accounts" href="/people/blocked" />
      </Section>

      <Section title="Notifications">
        <Row
          label="In-app notifications"
          trailing={
            <NotificationToggle
              enabled={user.prefs.notify_in_app !== false}
            />
          }
        />
      </Section>

      <Section title="Vault">
        <Row label="Open vault" href="/vault" />
      </Section>

      <Section title="Invite">
        <Row label="Your referral code" value={user.referral_code} />
        {user.referred_by ? (
          <Row label="Referred by" value={user.referred_by} />
        ) : null}
      </Section>

      <Section title="About">
        <Row label="Version" value="0.1.0" />
        <Row label="Sign out" trailing={<SignOutButton />} />
        <Row label="Deactivate or delete" href="/settings/leaving" isDanger />
      </Section>
    </div>
  );
}
