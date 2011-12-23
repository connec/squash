fs       = require 'fs'
path     = require 'path'
{Squash} = require '../lib/squash'

usage = """
  
  Squash makes NodeJS projects work in the browser by takes a number of initial
  requires and squashing them and their dependencies into a Javascript with a
  browser-side require wrapper.
  
  NOTE: Core modules will not work (Squash cannot find their source files).
  
  Usage:
    squash [options] requires
  
  Options:
    --coffee        Register the '.coffee' extension to support CoffeeScript
                    files (requires the 'coffee-script' module)
    --compress  -c  Compress result with uglify-js (otherwise result is
                    beautified)
    --help      -h  Print this notice
    --file      -f  A file to write the result to
    --watch     -w  Watch all found requires and rebuild on changes (for best
                    results an output file should be specified)
  
  E.g.:
    squash --coffee -o lib/project.js -w ./src/project
"""

options =
  compress:   false
  extensions: []
  file:       null
  requires:   []

args = process.argv.slice 2
skip = false
for arg, i in args
  if skip
    skip = false
    continue
  
  switch arg
    when '--coffee'
      coffee = require 'coffee-script'
      options.extensions['.coffee'] = (x) ->
        coffee.compile fs.readFileSync x, 'utf8'
    when '--compress', '-c'
      options.compress = true
    when '--help', '-h'
      console.log usage
      return
    when '--file', '-f'
      options.file = args[i + 1]
      skip         = true
    else
      options.requires.push arg

if options.requires.length is 0
  console.log usage
else
  squash     = new Squash options
  squash.cwd = path.dirname process.cwd
  result     = squash.squash()
  if options.file
    fs.writeFileSync options.file, result
  else
    console.log result