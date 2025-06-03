import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

import tailwindcss from '@tailwindcss/vite'

import topLevelAwait from "vite-plugin-top-level-await"

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss(), topLevelAwait()],
  optimizeDeps: {
    exclude: ['@otp-interop/web-socket-dist']
  },
})
