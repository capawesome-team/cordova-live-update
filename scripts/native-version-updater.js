// Custom `commit-and-tag-version` updater for the plugin version constant
// reported to the server as `pluginVersion`. Matches both the Android
// (`public static final String VERSION = "..."`) and iOS
// (`public static let version = "..."`) declarations.
const VERSION_REGEX = /((?:public static final String VERSION|public static let version)\s*=\s*")([^"]*)(")/;

module.exports.readVersion = function (contents) {
  const match = contents.match(VERSION_REGEX);
  return match ? match[2] : undefined;
};

module.exports.writeVersion = function (contents, version) {
  return contents.replace(VERSION_REGEX, `$1${version}$3`);
};
