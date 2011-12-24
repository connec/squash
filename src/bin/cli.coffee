fs       = require 'fs'
path     = require 'path'
{Squash} = require '../lib/squash'

options =
  compress:   false
  extensions: []
  file:       null
  requires:   []
  watch:      false

output = (result) ->
  if options.file
    fs.writeFileSync options.file, result
  else
    console.log result

usage = -> 
  console.log """
    Squash makes NodeJS projects work in the browser by takes a number of initial
    requires and squashing them and their dependencies into a Javascript with a
    browser-side require wrapper.
    
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
  """

args = process.argv.slice 2
skip = false
stop = false
for arg, i in args
  if skip
    skip = false
    continue
  
  if stop
    options.requires.push arg
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
    when '--obfuscate', '-o'
      options.obfuscate = true
    when '--watch', '-w'
      options.watch = true
    else
      stop = true
      options.requires.push arg

if options.requires.length is 0
  console.log usage
else
  squash     = new Squash options
  squash.cwd = path.dirname process.cwd
  if options.watch
    console.log 'Watching file for changes. Press ^C to terminate'
    squash.watch (result) ->
      console.log "rebuid @ #{new Date}"
      output result
  else
    output squash.squash()