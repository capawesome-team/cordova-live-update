// Bundles the TypeScript output into a single CommonJS file consumed by
// Cordova's `<js-module>` mechanism. Cordova evaluates the file in a wrapper
// that captures `module.exports` and assigns it to the `<clobbers>` target
// (`cordova.plugins.LiveUpdate`).
export default {
  input: 'dist/esm/index.js',
  output: {
    file: 'dist/plugin.js',
    format: 'cjs',
    exports: 'default',
    sourcemap: true,
    inlineDynamicImports: true,
  },
};
