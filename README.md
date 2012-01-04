# Squash

## Why?

Squash was built to simplify building browser-compatible scripts from libraries
written and tested with NodeJS.

## How?

Squash locates your initial requires (the ones you want to execute in the
browser) using the `require.resolve` algorithm used by Node.  The code in that
file is then searched for further dependencies and so on until all dependencies
have been found.  The code is then combined into a single script which will work
as expected on the browser or even in Node.

## Installation

    npm install squash

## Usage

### Command Line

    squash [options] <require[=alias]...>

#### Options

    --coffee           Register the '.coffee' extension to support CoffeeScript
                       files (requires the 'coffee-script' module)
    --compress     -c  Compress result with uglify-js (otherwise result is
                       beautified)
    --help         -h  Print this notice
    --file <file>  -f  A file to write the result to
    --obfuscate    -o  Replaces all non-essential paths with dummy values
    --relax        -r  Continues when modules cannot be found.  Useful if a
                       core module is required conditionally.
    --watch        -w  Watch all found requires and rebuild on changes (for best
                       results an output file should be specified)

#### Example

To bundle `src/index.coffee` and all its dependencies to `lib/project.js` every
time a dependency changes, and make it available as `window.project` (without
the alias, it would be as `window['./src']`):

    squash --coffee -f lib/project.js -w ./src=project

### API

```coffeescript
# build.coffee
coffeescript = require 'coffee-script'
fs           = require 'fs'
{Squash}     = require 'squash'

squash = new Squash requires: ['./src'], extensions:
  '.coffee': (x) -> coffeescript.compile fs.readFileSync x, 'utf8'
fs.writeFileSync 'lib/project.js', squash.squash()
```

### Browser

Having built your `lib/project.js` you can run your project in the browser with:

```html
<script src='lib/project.js'></script>
<script>
  var project = require('./src');
  project.do_awesome_things();
</script>
```

If, for some reason, you want access to all the dependent modules they are
available in `require.cache`.

### Node

You can also load packages with Node should you wish:

```coffeescript
project = require('./lib/project').require './src'
project.do_awesome_things();
```

## Limitations

* The 'compatibility layer' is currently very lightweight.  Scripts are given
  `global`, `module` (`= { exports: {} }`), `exports` and `require` variables
  (also `this === exports === modules.exports`).  Additional properties may be
  added to `module` to improve compatibility in future versions.

* For the above reason, libraries such as jQuery that have vastly different
  dependencies on Node (`jsdom` etc.) than in the browser (DOM) do not work
  terribly well 'cross-platform' in this way.  The easiest option here is to use
  the `global` variable to access the browser's `window` object, allowing you to
  include the library normally in the browser or attach it to `global` in Node.

* There is no support for core Node modules such as `path`, `fs`, etc.

* It doesn't attempt to provide any 'resolve' functionality inside the package,
  so only the given initial dependencies will be available using `require`
  (though other dependencies can be found in `require.cache` if you're
  desparate).

## Bugs etc.

If you find a bug or think something could be done better don't hesitate to
submit an issue and/or pull request.