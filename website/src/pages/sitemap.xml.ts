import type { APIRoute } from 'astro';
import { paths } from '../i18n/strings';

// every page with its language alternates, so Google pairs EN and DE
export const GET: APIRoute = ({ site }) => {
  const abs = (p: string) => new URL(p, site).href;
  const urls = (['home', 'privacy'] as const).flatMap((page) =>
    (['en', 'de'] as const).map((lang) => {
      const alts = (['en', 'de'] as const)
        .map((l) => `<xhtml:link rel="alternate" hreflang="${l}" href="${abs(paths[l][page])}"/>`)
        .join('');
      return `<url><loc>${abs(paths[lang][page])}</loc>${alts}</url>`;
    }),
  );
  const xml = `<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">${urls.join('')}</urlset>`;
  return new Response(xml, { headers: { 'Content-Type': 'application/xml' } });
};
