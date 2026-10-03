// The launcher's five colour themes (lib/design_tokens.dart): ground,
// cards, text, quieter text, accent, lines. Shared by the inline script that
// applies a saved choice before the first paint and by scripts/design.ts.

export type ThemeId = 'grey' | 'rose' | 'green' | 'blue' | 'dark';
export type Theme = { ground: string; card: string; ink: string; ink2: string; accent: string; line: string };

export const THEMES: Record<ThemeId, Theme> = {
  grey: { ground: '#f4f3f0', card: '#ffffff', ink: '#1b1a17', ink2: '#6c6860', accent: '#a15b2d', line: '#e4e1da' },
  rose: { ground: '#f7f1f1', card: '#fffbfb', ink: '#20191a', ink2: '#756264', accent: '#a63d5c', line: '#ebdddf' },
  green: { ground: '#f0f3ef', card: '#fbfdfa', ink: '#181c18', ink2: '#5f6b5f', accent: '#3f7a52', line: '#dce3d9' },
  blue: { ground: '#eff2f5', card: '#fafcfd', ink: '#171b1f', ink2: '#5c6874', accent: '#2e6c8e', line: '#dce3e9' },
  dark: { ground: '#121211', card: '#1d1c1a', ink: '#f2f0ec', ink2: '#a09c94', accent: '#d98a4a', line: '#33322e' },
};
export const THEME_ORDER: ThemeId[] = ['grey', 'rose', 'green', 'blue', 'dark'];

/** What a visitor picked; stored in their browser only (see the privacy page). */
export type DesignState = { theme: ThemeId | null; r: number; sh: number };
export const DESIGN_KEY = 'hl-design';
export const DESIGN_DEFAULT: DesignState = { theme: null, r: 24, sh: 0.5 };
