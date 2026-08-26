import type { Config } from 'tailwindcss';

const config: Config = {
  darkMode: ['class', '[data-theme="dark"]'],
  content: [
    './src/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        navy: {
          DEFAULT: '#0F2747',
          dark: '#0A1B33',
          light: '#1A3A5C',
          surface: '#122544',
        },
        sky: {
          DEFAULT: '#1FA3C8',
          light: '#7BC4E8',
          dark: '#167A99',
          glow: 'rgba(31, 163, 200, 0.25)',
        },
        accent: {
          green: '#16D97A',
          amber: '#F5A623',
          coral: '#FF6B6B',
        },
        bg: {
          primary: 'var(--color-bg-primary)',
          secondary: 'var(--color-bg-secondary)',
          tertiary: 'var(--color-bg-tertiary)',
        },
        text: {
          primary: 'var(--color-text-primary)',
          secondary: 'var(--color-text-secondary)',
          muted: 'var(--color-text-muted)',
        },
        border: {
          default: 'var(--color-border-default)',
          subtle: 'var(--color-border-subtle)',
        },
      },
      fontFamily: {
        display: ['var(--font-display)', 'Cairo', 'Sora', 'sans-serif'],
        body: ['var(--font-body)', 'Cairo', 'DM Sans', 'sans-serif'],
        mono: ['var(--font-mono)', 'JetBrains Mono', 'monospace'],
      },
      boxShadow: {
        glow: '0 0 32px rgba(31, 163, 200, 0.25)',
        card: '0 4px 20px rgba(10, 27, 51, 0.15)',
        elevated: '0 12px 36px rgba(10, 27, 51, 0.25)',
      },
      borderRadius: {
        xl: '16px',
        '2xl': '24px',
      },
    },
  },
  plugins: [],
};

export default config;
