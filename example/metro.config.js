const path = require('path');
const { getDefaultConfig } = require('@react-native/metro-config');
const { withMetroConfig } = require('react-native-monorepo-config');

// The app uses the source of the wrapper in the folder above, with the react and react-native of this app.
module.exports = withMetroConfig(getDefaultConfig(__dirname), {
  root: path.resolve(__dirname, '..'),
  dirname: __dirname,
  conditions: ['codelloy-react-native-source'],
});
