fs     = require 'fs'
path   = require 'path'
uglify = require 'uglify-js'
util   = require 'util'

class exports.Squash
  # Initialize a new instance with given options
  constructor: (options = {}) ->
    # Directories to search for node_modules
    @node_path = if process.env.NODE_PATH
      process.env.NODE_PATH.split (if '\\' in process.env.NODE_PATH then /;/g else /:/g)
    else
      []
    
    # The extension of the last resolved file
    @ext = null
    
    # The details of all the discovered modules
    @modules = {}
    
    # Contains the module file names in the order they should be output
    @ordered = []
    
    # Set up the options
    @options =
      compress:   false
      cwd:        path.dirname module.parent.filename
      extensions: {}
      obfuscate:  false
      requires:   []
    @options[key] = value for key, value of options
    
    # Set up the extensions
    @extensions =
      '.js': (x) -> fs.readFileSync x, 'utf8'
    @extensions[ext] = callback for ext, callback of @options.extensions
  
  # Watch the initial requires and their dependencies for changes and execute
  # the callback with the reconstructed script.
  watch: (callback) ->
    # Require the initial dependencies to build the initial watchlist
    callback @squash()
    
    for file in @ordered
      do (file) =>
        skip = false
        fs.watch file, (event, filename = file) =>
          return if skip
          skip = true
          @modules = {}
          @ordered = []
          setTimeout =>
            callback @squash()
            skip = false
          , 25
  
  # Produce a script combining the initial requires and all their dependencies
  squash: ->
    # Require the initial dependencies
    @require path, @options.cwd for path in @options.requires
    
    # Build the initial boilerplate
    output = """
      ;(function() {;
        var modules = {};
        var require_from = function(from) {
          return (function(name) {
            if(modules[from] && modules[from][name]) {
              if(modules[from][name].initialize)
                modules[from][name].initialize();
              return modules[from][name].exports;
            } else {
              throw new Error('could not find module ' + name);
            }
          });
        };
        var register = function(names, directory, callback) {
          var module  = {
            exports: {},
            initialize: function() {
              callback.call(exports, module, exports, require_from(directory));
              delete module.initialize;
            }
          };
          var exports = module.exports;
          
          for(var from in names) {
            modules[from] = modules[from] || {};
            for(var j in names[from]) {
              var name = names[from][j];
              modules[from][name] = module;
            }
          }
        };
        this.modules = modules;
        this.require = require_from('');
    """
    
    obfuscated = {'': ''}
    id         = 0
    obfuscate  = (names) ->
      result = {}
      result[obfuscated[from] ?= id++] = names[from] for from of names
      return result
    
    for file in @ordered
      module = @modules[file]
      
      {directory, names} = module
      if @options.obfuscate
        directory = (obfuscated[directory] ?= id++)
        names     = obfuscate names
      
      # Add the code to register the module
      output += """
        ;register(#{util.inspect names}, #{util.inspect directory}, function(module, exports, require) {;
          #{module.js}
        ;});
      """
    output += '\n;}).call(this);'
    
    # Beautify or compress the output
    ast = uglify.parser.parse output
    if @options.compress
      ast    = uglify.uglify.ast_squeeze uglify.uglify.ast_mangle ast
      output = uglify.uglify.gen_code ast
    else
      output = uglify.uglify.gen_code ast, beautify: true
    
    return output
  
  # Load the details of the given module and recurse for its dependencies
  require: (name, from) ->
    # Resolve `path` to a source file, treating `path` as relative to `from`
    file = @resolve name, from
    
    # If this module has already been required, register the path and move on
    if @modules[file]?
      names = (@modules[file].names[path.relative @options.cwd, from] ?= [])
      names.push name unless name in names
      return
    
    # Register the source as a module
    @modules[file] =
      directory: path.relative @options.cwd, path.dirname file
      js:        @extensions[@ext] file
      names:     {}
    @modules[file].names[path.relative @options.cwd, from] = [name]
    
    # Recurse for the module's dependencies
    @require dependency, path.dirname file for dependency in @gather_dependencies file
    
    # Finally, register this module in its correct order
    @ordered.push file
  
  # Find required dependencies using a walk of the AST
  gather_dependencies: (file) ->
    dependencies = []
    ast          = uglify.parser.parse @modules[file].js
    walker       = uglify.uglify.ast_walker()
    walker.with_walkers call: ([_, name], args) ->
      # Add a dependency if the function is 'require' and the first argument is a string
      if name is 'require' and args.length and args[0][0] is 'string'
        dependencies.push args[0][1]
    , ->
      walker.walk ast
    return dependencies
  
  # Attempts to resolve a module's file given the required string and a base location
  resolve: (name, from) ->
    # Compute the absolute path
    file = path.resolve from, name
    
    # If it's a relative import...
    if name[0...1] is '/' or name[0...2] is './' or name[0...3] is '../'
      # Try to load it as a file
      return resolved if resolved = @load_as_file file
      
      # Try to load it as a directory
      return resolved if resolved = @load_as_directory file
    
    # Otherwise, try to load it as a node module
    return resolved if resolved = @load_node_module name, from
    
    # If we reach here the module could not be found, throw an error
    throw new Error "could not find module #{name}"
  
  # Attempt to load the given path as a file
  load_as_file: (file) ->
    if path.existsSync(file) and fs.statSync(file).isFile()
      # The path exists and is a file, return it unchanged
      @ext = file[file.lastIndexOf('.')..] || '.js'
      return file
    for ext of @extensions
      # Try registered extensions
      return resolved if path.existsSync (resolved = file + (@ext = ext))
    return false
  
  # Attempt to load the given path as a directory
  load_as_directory: (dir) ->
    # Attempt to load the `main` attribute from package.json
    if path.existsSync (package = path.resolve dir, 'package.json')
      package = JSON.parse fs.readFileSync package, 'utf8'
      if package.main
        name = path.resolve dir, package.main
        return resolved if resolved = @load_as_file name
        return resolved if resolved = @load_as_directory name
    for ext of @extensions
      # Try registered extensions with an 'index' file
      return resolved if path.existsSync (resolved = path.resolve dir, 'index' + (@ext = ext))
    return false
  
  # Attempt to load the given path as a node module
  load_node_module: (module, from) ->
    for dir in @node_modules_dirs(from).concat @node_path
      return resolved if resolved = @load_as_file path.join dir, module
      return resolved if resolved = @load_as_directory path.join dir, module
    return false
  
  # Generate an array of 'node_modules' paths for the current directory
  node_modules_dirs: (from) ->
    parts = from.split /\\|\//g
    root  = if (i = parts.indexOf 'node_modules') isnt -1 then i else 0
    i     = parts.length - 1
    dirs  = []
    for i in [i...root]
      continue if parts[i] is 'node_modules'
      dirs.push path.join.apply path, parts[0..i].concat ['node_modules']
    return dirs