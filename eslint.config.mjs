// @ts-check
import eslint from '@eslint/js';
import tseslintPlugin from '@typescript-eslint/eslint-plugin';
import tseslintParser from '@typescript-eslint/parser';
import prettier from 'eslint-config-prettier';

export default [
  {
    ignores: ['dist/**', 'node_modules/**', 'coverage/**', '**/*.js', '**/*.d.ts'],
  },
  eslint.configs.recommended,
  {
    files: ['**/*.ts'],
    plugins: { '@typescript-eslint': tseslintPlugin },
    languageOptions: { parser: tseslintParser },
    rules: {
      ...tseslintPlugin.configs['eslint-recommended'].overrides[0].rules,
      ...tseslintPlugin.configs.recommended.rules,
      '@typescript-eslint/no-explicit-any': 'off',
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
      '@typescript-eslint/explicit-function-return-type': 'off',
      '@typescript-eslint/no-non-null-assertion': 'off',
      '@typescript-eslint/require-await': 'off',
      'no-console': 'warn',
    },
  },
  prettier,
];
