import path from 'node:path'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import RubyPlugin from 'vite-plugin-ruby'

export default defineConfig({
  plugins: [react(), RubyPlugin()],
  server: {
    fs: {
      allow: [path.resolve(__dirname, '../..')],
    },
  },
})
