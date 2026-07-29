import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'path';

// The site is served from GitHub Pages at /gamo/, and it shares docs/ with the
// exported Godot builds. emptyOutDir MUST stay false: wiping the output folder
// would delete docs/motorio, docs/motorio-oneshot and docs/nowhere.
export default defineConfig({
  base: '/gamo/',
  plugins: [react()],
  build: {
    outDir: resolve(__dirname, '../docs'),
    emptyOutDir: false,
    assetsDir: 'site-assets',
    rollupOptions: {
      input: {
        main: resolve(__dirname, 'index.html'),
        doc: resolve(__dirname, 'doc/index.html'),
      },
    },
  },
});
