const path = require('path');
const { getConfig } = require('react-native-builder-bob/babel-config');
const pkg = require('../package.json');

module.exports = getConfig(
  { presets: ['module:@react-native/babel-preset'] },
  { root: path.resolve(__dirname, '..'), pkg }
);
