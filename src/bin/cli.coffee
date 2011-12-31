fs       = require 'fs'
path     = require 'path'
{Squash} = require '../lib/squash'

options =
  compress  : false
  cwd       : path.resolve '.'
  extensions: []
  file      : null
  relax     : false
  requires  : []
  watch     : false

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
      squash [options] <requires...>
    
    Options:
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
    
    E.g.:
      squash --coffee -f lib/project.js -w ./src/project
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
      usage()
      return
    when '--file', '-f'
      options.file = args[i + 1]
      skip         = true
    when '--obfuscate', '-o'
      options.obfuscate = true
    when '--relax', '-r'
      options.relax = (name, from) ->
        message = "Warn: could not find module #{name}"
        unless options.obfuscate
          message += " from #{from}"
        console.log message
    when '--watch', '-w'
      options.watch = true
    else
      stop = true
      options.requires.push arg

if options.requires.length is 0
  usage()
else
  squash     = new Squash options
  squash.cwd = path.dirname process.cwd
  if options.watch
    console.log 'Watching file for changes. Press ^C to terminate\n---'
    squash.watch (error, result) ->
      if error?
        console.log "#{error}\n---"
      else
        console.log "rebuild @ #{new Date}\n---"
        output result
  else
    output squash.squash()