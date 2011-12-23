fs     = require 'fs'
path   = require 'path'
uglify = require 'uglify-js'
util   = require 'util'

class exports.Squash
  options:
    compress:   false
    extensions: {}
    requires:   []
  
  extensions:
    '.js': (x) -> fs.readFileSync x, 'utf8'
  
  constructor: (options = {}) ->
    @node_path = if process.env.NODE_PATH then process.env.NODE_PATH.split(/:|;/g) else []
    @cwd       = path.dirname module.parent.filename
    @ext       = null
    @modules   = {}
    @ordered   = []
    
    for name, value of options
      @options[name] = value
    @extensions[ext] = callback for ext, callback of @options.extensions
  
  squash: ->
    @require path, @cwd for path in @options.requires
    
    output = """
      ;(function() {;
        var modules = {};
        var require_from = function(from) {
          return (function(name) {
            if(modules[from] && modules[from][name]) {
              return modules[from][name];
            } else {
              throw new Error('could not find module ' + name);
            }
          });
        };
        var register = function(names, directory, callback) {
          var module  = {exports: {}};
          var exports = module.exports;
          callback.call(exports, module, exports, require_from(directory));
          
          for(var from in names) {
            modules[from] = modules[from] || {};
            for(var j in names[from]) {
              var name = names[from][j];
              modules[from] = modules[from] || {};
              modules[from][name] = module.exports;
            }
          }
        };
        this.exports = modules;
        this.require = require_from('#{@cwd.replace /\\/g, '\\\\'}');
    """
    for file in @ordered
      module = @modules[file]
      output += """
        ;register(#{util.inspect module.names}, '#{module.directory.replace /\\/g, '\\\\'}', function(module, exports, require) {;
          #{module.js}
        ;});
      """
    output += '\n;}).call(this);'
    
    ast = uglify.parser.parse output
    if @options.compress
      ast    = uglify.uglify.ast_squeeze uglify.uglify.ast_mangle ast
      output = uglify.uglify.gen_code ast
    else
      output = uglify.uglify.gen_code ast, beautify: true
    return output
  
  require: (name, from) ->
    # Resolve `path` to a source file, treating `path` as relative to `from`
    file = @resolve name, from
    
    # If this module has already been required, register the path and move on
    if @modules[file]?
      names = (@modules[file].names[from] ?= [])
      names.push name unless name in names
      return
    
    # Register the source as a module
    @modules[file] =
      directory: path.dirname file
      js:        fs.readFileSync file, 'utf8'
      names:    {}
    @modules[file].names[from] = [name]
    
    # Require any of this module's dependencies
    @require dependency, @modules[file].directory for dependency in @gather_dependencies file
    
    # Finally, register this module in its correct order
    @ordered.push file
  
  gather_dependencies: (file) ->
    dependencies = []
    ast          = uglify.parser.parse @modules[file].js
    walker       = uglify.uglify.ast_walker()
    walker.with_walkers call: ([_, name], args) ->
      if name is 'require' and args.length and args[0][0] is 'string'
        dependencies.push args[0][1]
    , -> walker.walk ast
    return dependencies
  
  resolve: (x, from) ->
    y = path.resolve from, x
    if x[0...1] is '/' or x[0...2] is './' or x[0...3] is '../'
      return resolved if resolved = @load_as_file y
      return resolved if resolved = @load_as_directory y
    return resolved if resolved = @load_node_module x
    throw new Error "could not find module #{x}"
  
  load_as_file: (x) ->
    if path.existsSync(x) and fs.statSync(x).isFile()
      @ext = x[x.lastIndexOf('.')..] || '.js'
      return x
    for ext of @extensions
      return y if path.existsSync (y = x + (@ext = ext))
    return false
  
  load_as_directory: (x) ->
    if path.existsSync (y = x + '/package.json')
      package = JSON.parse fs.readFileSync y, 'utf8'
      return @load_as_file path.resolve(x, package.main) if package.main
    for ext of @extensions
      return y if path.existsSync (y = x + '/index' + (@ext = ext))
    return false
  
  load_node_module: (x) ->
    for dir in @node_modules_dirs().concat @node_path
      return resolved if resolved = @load_as_file path.join dir, x
      return resolved if resolved = @load_as_directory path.join dir, x
    return false
    
  node_modules_dirs: ->
    parts = @cwd.split /\\|\//g
    root  = if (i = parts.indexOf 'node_modules') isnt -1 then i else 0
    i     = parts.length - 1
    dirs  = []
    for i in [i...root]
      continue if parts[i] is 'node_modules'
      dirs.push path.join.apply path, parts[0..i].concat ['node_modules']
    return dirs