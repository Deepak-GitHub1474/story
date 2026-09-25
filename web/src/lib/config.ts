const ENVIRONMENTS = {
  development: {
    api: 'http://127.0.0.1:9000/v1',
    site: 'http://localhost:3100',
  },
  production: {
    api: 'https://story-storyapi-wicta2-e768a5-35-188-103-96.sslip.io/v1',
    site: 'https://story-six-chi.vercel.app',
  },
};

const APP_ENV = (process.env.NEXT_PUBLIC_STORY_ENV ?? 'development').toLowerCase();
const current = APP_ENV === 'production' ? ENVIRONMENTS.production : ENVIRONMENTS.development;
const API_ORIGIN = current.api.replace(/\/v1\/?$/, '');

export const API_BASE_URL = current.api;
export const SITE_URL = current.site;
export const SITE_NAME = 'STORY';

export function mediaUrl(path: string): string {
  return /^https?:\/\//.test(path) ? path : `${API_ORIGIN}${path}`;
}
