// Signs Android release builds with YOUR upload key when its details are provided,
// and falls back to the debug key otherwise (handy for local test builds).
//
// Provide the key WITHOUT committing secrets, e.g. as environment variables:
//   ORG_GRADLE_PROJECT_MOCHINOOK_UPLOAD_STORE_FILE=/abs/path/mochinook-upload.jks
//   ORG_GRADLE_PROJECT_MOCHINOOK_UPLOAD_STORE_PASSWORD=...
//   ORG_GRADLE_PROJECT_MOCHINOOK_UPLOAD_KEY_ALIAS=mochinook-upload
//   ORG_GRADLE_PROJECT_MOCHINOOK_UPLOAD_KEY_PASSWORD=...
// (or put the same keys, without the ORG_GRADLE_PROJECT_ prefix, in ~/.gradle/gradle.properties).
const { withAppBuildGradle } = require('expo/config-plugins');

const RELEASE_CONFIG = `
        release {
            if (project.hasProperty('MOCHINOOK_UPLOAD_STORE_FILE')) {
                storeFile file(project.property('MOCHINOOK_UPLOAD_STORE_FILE'))
                storePassword project.property('MOCHINOOK_UPLOAD_STORE_PASSWORD')
                keyAlias project.property('MOCHINOOK_UPLOAD_KEY_ALIAS')
                keyPassword project.property('MOCHINOOK_UPLOAD_KEY_PASSWORD')
            }
        }`;

module.exports = function withReleaseSigning(config) {
  return withAppBuildGradle(config, (cfg) => {
    let src = cfg.modResults.contents;
    if (!src.includes("MOCHINOOK_UPLOAD_STORE_FILE")) {
      src = src.replace(/signingConfigs\s*\{/, (m) => `${m}${RELEASE_CONFIG}`);
      src = src.replace(
        /(release\s*\{[^}]*?)signingConfig signingConfigs\.debug/,
        "$1signingConfig project.hasProperty('MOCHINOOK_UPLOAD_STORE_FILE') ? signingConfigs.release : signingConfigs.debug",
      );
    }
    cfg.modResults.contents = src;
    return cfg;
  });
};
