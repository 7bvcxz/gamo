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
        // The game itself owns /gamo/motorio-oneshot/, so its pages live in
        // subdirectories under it rather than replacing it.
        // Each game owns its documentation under its own path, so restructuring
        // one game's docs never touches another's.
        oneshotDoc: resolve(__dirname, 'motorio-oneshot/doc/index.html'),
        motorioDoc: resolve(__dirname, 'motorio/doc/index.html'),
        graphic: resolve(__dirname, 'motorio-oneshot/graphic/index.html'),
        proposals: resolve(__dirname, 'motorio-oneshot/graphic/proposals/index.html'),
      },
    },
  },
});
