// Custom `commit-and-tag-version` updater for the `version` attribute of the
// `<plugin>` element in `plugin.xml`. Anchored on `<plugin` so it never touches
// the `<?xml version="1.0"?>` declaration.
const VERSION_REGEX = /(<plugin\b[\s\S]*?\bversion=")([^"]*)(")/;

module.exports.readVersion = function (contents) {
  const match = contents.match(VERSION_REGEX);
  return match ? match[2] : undefined;
};

module.exports.writeVersion = function (contents, version) {
  return contents.replace(VERSION_REGEX, `$1${version}$3`);
};
