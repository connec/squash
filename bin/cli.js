(function() {
  var Squash, arg, args, coffee, i, options, skip, squash, usage, _len;

  Squash = require('../squash').Squash;

  args = process.argv.slice(2);

  squash = new Squash;

  usage = "\nSquash makes NodeJS projects work in the browser by takes a number of initial\nrequires and squashing them and their dependencies into a Javascript with a\nbrowser-side require wrapper.\n\nNOTE: Core modules will not work (Squash cannot find their source files).\n\nUsage:\n  squash [options] requires\n\nOptions:\n  --coffee        Register the '.coffee' extension to support CoffeeScript\n                  files (requires the 'coffee-script' module)\n  --compress  -c  Compress result with uglify-js (otherwise result is\n                  beautified)\n  --help      -h  Print this notice\n  --output    -o  A file to write the result to\n  --watch     -w  Watch all found requires and rebuild on changes (for best\n                  results an output file should be specified)\n\nE.g.:\n  squash --coffee -o lib/project.js -w ./src/project";

  options = {
    compress: false,
    extensions: [],
    output: null,
    requires: []
  };

  skip = false;

  for (i = 0, _len = args.length; i < _len; i++) {
    arg = args[i];
    if (skip) {
      skip = false;
      continue;
    }
    switch (arg) {
      case '--coffee':
        coffee = require('coffee-script');
        options.extensions['.coffee'] = function(x) {
          return coffee.compile(fs.readFileSync(x, 'utf8'));
        };
        break;
      case '--compress':
      case '-c':
        options.compress = true;
        break;
      case '--help':
      case '-h':
        console.log(usage);
        return;
      case '--output':
      case '-o':
        options.output = arg[i + 1];
        skip = true;
        break;
      default:
        options.requires.push(arg);
    }
  }

  if (options.requires.length === 0) {
    console.log(usage);
  } else {
    console.log((new Squash(options)).squash());
  }

}).call(this);
