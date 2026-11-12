module.exports = function (api) {
  api.cache(true);
  return {
    // babel-preset-expo would add the worklets plugin on its own; we turn that off
    // and list it ourselves so it is guaranteed to run exactly once, as the LAST plugin
    // (required by react-native-reanimated 4 and react-native-executorch).
    presets: [['babel-preset-expo', { worklets: false }]],
    plugins: ['react-native-worklets/plugin'],
  };
};
