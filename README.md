Squash
===

Squash is a tool that builds a browser-compatible script from your NodeJS
modules.  It does this by taking some initial dependencies, finding all their
dependencies, and concatenating them all together with a require/module/exports
compatibility wrapper.

NOTE: Core modules will not work (Squash cannot find their source files).

Usage:
  squash [options] requires

Options:
  --coffee         Register the '.coffee' extension to support CoffeeScript
                   files (requires the 'coffee-script' module)
  --compress   -c  Compress result with uglify-js (otherwise result is
                   beautified)
  --help       -h  Print this notice
  --file       -f  A file to write the result to
  --obfuscate  -o  Replaces all non-essential paths with dummy values
  --watch      -w  Watch all found requires and rebuild on changes (for best
                   results an output file should be specified)

E.g.:
  squash --coffee -o lib/project.js -w ./src/project