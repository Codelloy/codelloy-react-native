const path = require('path');
const { getDefaultConfig } = require('@react-native/metro-config');
const { withMetroConfig } = require('react-native-monorepo-config');

// The app uses the source of the wrapper in the folder above, with the react and react-native of this app.
module.exports = withMetroConfig(getDefaultConfig(__dirname), {
  root: path.resolve(__dirname, '..'),
  dirname: __dirname,
  // No workspaces: the root package is the only package, and the tool adds it by its name.
  workspaces: [],
  conditions: ['codelloy-react-native-source'],
});
