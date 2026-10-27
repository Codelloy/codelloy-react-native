const path = require('path');
const pkg = require('../package.json');

// Autolinking of the wrapper in the folder above. It is not in node_modules of this app.
module.exports = {
  dependencies: {
    [pkg.name]: {
      root: path.join(__dirname, '..'),
      // Codegen fails without the platforms.
      platforms: { ios: {}, android: {} },
    },
  },
};
