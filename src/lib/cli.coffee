fs       = require 'fs'
path     = require 'path'
{Squash} = require './squash'

options =
  compress:   false
  cwd:        path.resolve '.'
  extensions: []
  file:       null
  relax:      false
  requires:   {}
  watch:      false

output = (result) ->
  if options.file
    fs.writeFileSync options.file, result
  else
    console.log result

usage = ->
  console.log """
    Squash makes NodeJS projects work in the browser by taking a number of initial
    requires and squashing them and their dependencies into a Javascript with a
    browser-side require wrapper.

    NOTE: Core modules will not work (Squash cannot find their source files).

    Usage:
      squash [options] <requires...>

    Options:
      --coffee           Register the '.coffee' extension to support CoffeeScript
                         files (requires the 'coffeescript' module)
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

  unless stop
    switch arg
      when '--coffee'
        coffee = require 'coffeescript'
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
        options.relax = new Function 'name', 'from', """
          var message = 'Warn: could not find module ' + name;
          #{if options.obfuscate then '' else 'message += \' from \' + from;'}
          console.log(message);
        """
      when '--watch', '-w'
        options.watch = true
      else
        stop = true

  if stop
    if '=' in arg
      arg = arg.split '='
      options.requires[arg[0]] = arg[1]
    else
      options.requires[arg] = arg

if options.requires.length is 0
  usage()
else
  squash     = new Squash options
  squash.cwd = path.dirname process.cwd()
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
