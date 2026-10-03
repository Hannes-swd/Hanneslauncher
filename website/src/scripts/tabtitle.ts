// While the tab is in the background, its title becomes a small ticker in
// the page's language ("we're waiting for you"), running along like the
// launcher's scrolling text. Coming back restores the real title at once.

const LINES: Record<string, string> = {
  de: 'Wir warten auf dich · hanneslauncher · ',
  en: 'We’re waiting for you · hanneslauncher · ',
};

export function initTabTitle() {
  const original = document.title;
  const text = LINES[document.documentElement.lang] ?? LINES.en;
  let timer = 0;
  let i = 0;
  document.addEventListener('visibilitychange', () => {
    clearInterval(timer);
    if (!document.hidden) {
      document.title = original;
      return;
    }
    i = 0;
    const tick = () => {
      document.title = text.slice(i) + text.slice(0, i);
      i = (i + 1) % text.length;
    };
    tick();
    // browsers slow timers in background tabs to about once a second, so
    // the ticker moves one letter a second there - still readable as motion
    timer = window.setInterval(tick, 300);
  });
}
