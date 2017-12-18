(function() {
  var Squash, arg, args, coffee, fs, i, j, len, options, output, path, skip, squash, stop, usage,
    indexOf = [].indexOf;

  fs = require('fs');

  path = require('path');

  ({Squash} = require('./squash'));

  options = {
    compress: false,
    cwd: path.resolve('.'),
    extensions: [],
    file: null,
    relax: false,
    requires: {},
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
    return console.log("Squash makes NodeJS projects work in the browser by taking a number of initial\nrequires and squashing them and their dependencies into a Javascript with a\nbrowser-side require wrapper.\n\nNOTE: Core modules will not work (Squash cannot find their source files).\n\nUsage:\n  squash [options] <requires...>\n\nOptions:\n  --coffee           Register the '.coffee' extension to support CoffeeScript\n                     files (requires the 'coffeescript' module)\n  --compress     -c  Compress result with uglify-js (otherwise result is\n                     beautified)\n  --help         -h  Print this notice\n  --file <file>  -f  A file to write the result to\n  --obfuscate    -o  Replaces all non-essential paths with dummy values\n  --relax        -r  Continues when modules cannot be found.  Useful if a\n                     core module is required conditionally.\n  --watch        -w  Watch all found requires and rebuild on changes (for best\n                     results an output file should be specified)\n\nE.g.:\n  squash --coffee -f lib/project.js -w ./src/project");
  };

  args = process.argv.slice(2);

  skip = false;

  stop = false;

  for (i = j = 0, len = args.length; j < len; i = ++j) {
    arg = args[i];
    if (skip) {
      skip = false;
      continue;
    }
    if (!stop) {
      switch (arg) {
        case '--coffee':
          coffee = require('coffeescript');
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
        case '--relax':
        case '-r':
          options.relax = new Function('name', 'from', `var message = 'Warn: could not find module ' + name;\n${(options.obfuscate ? '' : 'message += \' from \' + from;')}\nconsole.log(message);`);
          break;
        case '--watch':
        case '-w':
          options.watch = true;
          break;
        default:
          stop = true;
      }
    }
    if (stop) {
      if (indexOf.call(arg, '=') >= 0) {
        arg = arg.split('=');
        options.requires[arg[0]] = arg[1];
      } else {
        options.requires[arg] = arg;
      }
    }
  }

  if (options.requires.length === 0) {
    usage();
  } else {
    squash = new Squash(options);
    squash.cwd = path.dirname(process.cwd());
    if (options.watch) {
      console.log('Watching file for changes. Press ^C to terminate\n---');
      squash.watch(function(error, result) {
        if (error != null) {
          return console.log(`${error}\n---`);
        } else {
          console.log(`rebuild @ ${new Date}\n---`);
          return output(result);
        }
      });
    } else {
      output(squash.squash());
    }
  }

}).call(this);
