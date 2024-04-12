import gleam from "vite-gleam";

export default {
  plugins: [gleam()],
  server: {
    proxy: {
      '/ws': {
        target: 'ws://localhost:3000',
        ws: true,
      },
    },
  },
};
