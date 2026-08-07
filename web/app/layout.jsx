import './styles.css';

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
      <body>{children}</body>
    </html>
  );
}
