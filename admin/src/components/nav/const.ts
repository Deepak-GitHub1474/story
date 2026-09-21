export type StaffRole = 'moderator' | 'admin' | 'super_admin';

export const NAV_LINKS: { href: string; label: string; minRole: StaffRole }[] = [
  { href: '/queue', label: 'Queue', minRole: 'moderator' },
  { href: '/tickets', label: 'Tickets', minRole: 'moderator' },
  { href: '/users', label: 'Accounts', minRole: 'admin' },
  { href: '/audit', label: 'Audit', minRole: 'admin' },
  { href: '/vault', label: 'Escrow', minRole: 'super_admin' },
  { href: '/security', label: 'Security', minRole: 'moderator' },
];

export const ROLE_RANK: Record<string, number> = {
  moderator: 1,
  admin: 2,
  super_admin: 3,
};

export function linksFor(role: string) {
  const rank = ROLE_RANK[role] ?? 0;
  return NAV_LINKS.filter((link) => ROLE_RANK[link.minRole] <= rank);
}
