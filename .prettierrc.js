// Based on the prettier config used in @capawesome/capacitor-plugins.
module.exports = {
  arrowParens: 'avoid',
  bracketSpacing: true,
  jsxSingleQuote: false,
  quoteProps: 'consistent',
  semi: true,
  singleQuote: true,
  tabWidth: 2,
  trailingComma: 'all',
  plugins: ['prettier-plugin-java'],
  overrides: [
    {
      files: ['*.java'],
      options: {
        printWidth: 140,
        tabWidth: 4,
        useTabs: false,
        trailingComma: 'none',
      },
    },
  ],
};
