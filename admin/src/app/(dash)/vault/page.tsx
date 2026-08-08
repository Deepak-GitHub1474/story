import type { Metadata } from 'next';
import { redirect } from 'next/navigation';
import { requireStaff } from '@/lib/server/guard';
import { VaultLookup } from './VaultLookup';

export const metadata: Metadata = { title: 'Vault escrow' };

export default async function VaultEscrowPage() {
  const staff = await requireStaff();
  if (staff.role !== 'super_admin') redirect('/queue');

  return (
    <div className="max-w-2xl">
      <h1 className="text-[length:var(--text-title)] font-medium">Vault escrow</h1>

      <div className="mt-4 rounded-[length:var(--radius-md)] border border-danger bg-surface p-5">
        <h2 className="font-medium text-danger">Read before using this</h2>
        <ul className="mt-3 space-y-1.5 text-[length:var(--text-label)] leading-relaxed text-text-secondary">
          <li>You can see passcode names. Not values, not hashes, not key material.</li>
          <li>
            There is no endpoint that reads a vault item, and adding one would defeat
            the product.
          </li>
          <li>
            A release requires an open ticket from the account owner and a written
            justification. The material goes to the owner, never to you.
          </li>
          <li>
            A released passcode alone still decrypts nothing. It is one of two halves,
            and the other needs the owner&rsquo;s password.
          </li>
          <li>Every view and every release is written to the audit log the owner reads.</li>
        </ul>
      </div>

      <div className="mt-8">
        <VaultLookup />
      </div>
    </div>
  );
}
