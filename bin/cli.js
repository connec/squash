(function() {
  var Squash, arg, args, coffee, fs, i, options, output, path, skip, squash, stop, usage, _len;

  fs = require('fs');

  path = require('path');

  Squash = require('../lib/squash').Squash;

  options = {
    compress: false,
    cwd: path.resolve('.'),
    extensions: [],
    file: null,
    requires: [],
    watch: false
  };

  output = function(result) {
    if (options.file) {
      return fs.writeFileSync(options.file, result);
    } else {
      return console.log(result);
    }
  };

  usage = function() {
    return console.log("Squash makes NodeJS projects work in the browser by takes a number of initial\nrequires and squashing them and their dependencies into a Javascript with a\nbrowser-side require wrapper.\n\nNOTE: Core modules will not work (Squash cannot find their source files).\n\nUsage:\n  squash [options] requires\n\nOptions:\n  --coffee         Register the '.coffee' extension to support CoffeeScript\n                   files (requires the 'coffee-script' module)\n  --compress   -c  Compress result with uglify-js (otherwise result is\n                   beautified)\n  --help       -h  Print this notice\n  --file       -f  A file to write the result to\n  --obfuscate  -o  Replaces all non-essential paths with dummy values\n  --watch      -w  Watch all found requires and rebuild on changes (for best\n                   results an output file should be specified)\n\nE.g.:\n  squash --coffee -o lib/project.js -w ./src/project");
  };

  args = process.argv.slice(2);

  skip = false;

  stop = false;

  for (i = 0, _len = args.length; i < _len; i++) {
    arg = args[i];
    if (skip) {
      skip = false;
      continue;
    }
    if (stop) {
      options.requires.push(arg);
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
        usage();
        return;
      case '--file':
      case '-f':
        options.file = args[i + 1];
        skip = true;
        break;
      case '--obfuscate':
      case '-o':
        options.obfuscate = true;
        break;
      case '--watch':
      case '-w':
        options.watch = true;
        break;
      default:
        stop = true;
        options.requires.push(arg);
    }
  }

  if (options.requires.length === 0) {
    usage();
  } else {
    squash = new Squash(options);
    squash.cwd = path.dirname(process.cwd);
    if (options.watch) {
      console.log('Watching file for changes. Press ^C to terminate\n---');
      squash.watch(function(error, result) {
        if (error != null) {
          return console.log("" + error + "\n---");
        } else {
          console.log("rebuild @ " + (new Date) + "\n---");
          return output(result);
        }
      });
    } else {
      output(squash.squash());
    }
  }

}).call(this);
