import eslint from '@eslint/js';
import prettier from 'eslint-config-prettier';
import { defineConfig } from 'eslint/config';
import tseslint from 'typescript-eslint';

export default defineConfig(
  {
    ignores: [
      '**/node_modules/',
      'lib/',
      'example/ios/',
      'example/android/',
      '**/*.js',
      '**/*.mjs',
    ],
  },
  eslint.configs.recommended,
  tseslint.configs.strictTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },
  {
    // expect(Linking.getInitialURL) reads a jest mock, not a method that needs this.
    files: ['src/__tests__/**'],
    rules: { '@typescript-eslint/unbound-method': 'off' },
  },
  prettier
);
