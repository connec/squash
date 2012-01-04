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
      compress  : false
      cwd       : path.dirname module.parent.filename
      extensions: {}
      obfuscate : false
      relax     : false
      requires  : {}
    @options[key] = value for key, value of options
    
    # Set up the extensions
    @extensions =
      '.js': (x) -> fs.readFileSync x, 'utf8'
    @extensions[ext] = callback for ext, callback of @options.extensions
  
  # Watch the initial requires and their dependencies for changes and execute
  # the callback with the reconstructed script.
  watch: (callback) ->
    # Remember which files we are watching
    watchers = {}
    
    # Updates the watchers list based on the filenames discovered with the last
    # `@squash` operation
    update_watchers = =>
      new_watchers = {}
      for file in @ordered
        if file of watchers
          # If the file is already being watched just copy the watcher
          new_watchers[file] = watchers[file]
          continue
        
        # Otherwise create a watcher for the file
        do (file) => # We use `do` to create a `skip` flag for each file
          skip = false
          new_watchers[file] = fs.watch file, (event, filename = file) =>
            return if skip
            skip = true
            
            # Update after a short delay to ensure the file is available for
            # reading, and to ignore duplicate events
            setTimeout =>
              skip     = false
              @modules = {}
              @ordered = []
              
              try
                result = @squash()
                update_watchers()
                callback null, result
              catch error
                callback error
            , 25
      
      # Clear the watchers for any file no longer in the dependency tree
      for file, watcher of watchers
        watcher.close() if file not of new_watchers
      watchers = new_watchers
    
    # Start the first round of watchers
    callback null, @squash()
    update_watchers()
  
  # Produce a script combining the initial requires and all their dependencies
  squash: ->
    # Require the initial dependencies
    @require path, @options.cwd for path of @options.requires
    
    # Build the initial boilerplate
    output = """
      (function() {
        var root = this, modules, require_from, register, error;
        if(typeof global == 'undefined') {
          var global;
          if(typeof window != 'undefined') {
            global = window;
          } else {
            global = {};
          }
        }
        modules = {};
        require_from = function(from) {
          return (function(name) {
            if(modules[from] && modules[from][name]) {
              if(modules[from][name].initialize) {
                modules[from][name].initialize();
              }
              return modules[from][name].exports;
            } else {
              return error(name, from);
            }
          });
        };
        register = function(names, directory, callback) {
          var module  = {
            exports: {},
            initialize: function() {
              callback.call(module.exports, global, module, module.exports, require_from(directory), undefined);
              delete module.initialize;
            }
          };
          for(var from in names) {
            modules[from] = modules[from] || {};
            for(var j in names[from]) {
              var name = names[from][j];
              modules[from][name] = module;
            }
          }
        };
        error = 
    """
    if @options.relax
      if typeof @options.relax is 'function'
        output += "#{String @options.relax};"
      else
        output += 'function() { return null; };\n'
    else
      output += 'function(name, from) { throw new Error(\'could not find module \' + name); };\n'
    
    # Machinery for obfuscating paths
    obfuscated = {'': ''}
    id         = 0
    obfuscate  = (names) ->
      result = {}
      result[obfuscated[from] ?= id++] = names[from] for from of names
      return result
    
    for file in @ordered
      module = @modules[file]
      
      # Obfuscate the paths if the option is set
      {directory, names} = module
      if @options.obfuscate
        directory = (obfuscated[directory] ?= id++)
        names     = obfuscate names
      
      # Add the code to register the module
      output += """
        
        register(#{util.inspect names}, #{util.inspect directory}, function(global, module, exports, require, window) {
          #{module.js}
        });
        
      """
    
    # Add the code to register the initial requires on the root object
    for _, alias of @options.requires
      output += "root['#{alias}'] = require_from('')('#{alias}');\n"
    
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
    try
      # Resolve `path` to a source file, treating `path` as relative to `from`
      file = @resolve name, from
    catch error
      # If we're 'relaxed', just warn about the missing dependency
      if @options.relax
        if typeof @options.relax is 'function'
          @options.relax name, from
        return
      throw error
    
    # If this module has already been required, register the path and move on
    if @modules[file]?
      names = (@modules[file].names[path.relative @options.cwd, from] ?= [])
      names.push name unless name in names
      return
    
    # Register the source as a module
    @modules[file] =
      directory: path.relative @options.cwd, path.dirname file
      js       : @extensions[@ext] file
      names    : {}
    
    if from is @options.cwd and name of @options.requires
      name = @options.requires[name]
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