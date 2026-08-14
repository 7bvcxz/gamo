import './styles.css';
import { ThemeToggle } from '../components/ThemeToggle.jsx';

// Applied before the first paint, which is why it is a string in the head and
// not a useEffect. An effect runs after the browser has already painted, so a
// reader who chose dark would get a white flash on every navigation -- and this
// is a static export, so every navigation is a fresh document.
//
// Light unless dark was explicitly chosen. prefers-color-scheme is deliberately
// not consulted: the site looked different depending on whose laptop it was and
// there was no way to say otherwise.
const THEME_BOOT = `try{if(localStorage.getItem('gamo.theme')==='dark')document.documentElement.dataset.theme='dark'}catch(e){}`;

// One shell for every page. The Vite build had six hand-written index.html files
// that had drifted apart -- different meta tags, different titles, one missing a
// viewport -- which is the usual fate of copies. Per-page titles come from each
// route's own metadata export instead.
export const metadata = {
  title: 'Gamo — Godot 게임 모음',
  description: 'Godot로 만든 게임을 한곳에서 관리하고 브라우저에서 바로 실행합니다.',
};

export const viewport = {
  width: 'device-width',
  initialScale: 1,
};

export default function RootLayout({ children }) {
  return (
    <html lang="ko">
      <head>
        <script dangerouslySetInnerHTML={{ __html: THEME_BOOT }} />
      </head>
      <body>
        <ThemeToggle />
        {children}
      </body>
    </html>
  );
}
