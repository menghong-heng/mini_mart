import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    host: true, // bind 0.0.0.0 — required for Docker
    // Proxy /api/* to the FastAPI backend — avoids CORS in development
    // In Docker: VITE_API_TARGET=http://backend:8000
    // Locally:   defaults to http://localhost:8000
    proxy: {
      '/api': process.env.VITE_API_TARGET || 'http://localhost:8000',
    },
  },
})
