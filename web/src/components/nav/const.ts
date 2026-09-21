import type { TIconName } from '@/lib/icons';

export type NavItem = {
  href: string;
  label: string;
  icon: TIconName;
};

export const NAV_LINKS: NavItem[] = [
  { href: '/feed', label: 'Story', icon: 'story' },
  { href: '/activity', label: 'Activity', icon: 'activity' },
  { href: '/chats', label: 'Chat', icon: 'chat' },
  { href: '/profile', label: 'You', icon: 'you' },
];

export const DESKTOP_LINKS = [
  { href: '/feed', label: 'Stories' },
  { href: '/communities', label: 'Rooms' },
  { href: '/search', label: 'Search' },
  { href: '/activity', label: 'Activity' },
  { href: '/chats', label: 'Messages' },
];

export const MOBILE_ACTIONS: NavItem[] = [
  { href: '/search', label: 'Search', icon: 'search' },
  { href: '/communities', label: 'Rooms', icon: 'rooms' },
];
