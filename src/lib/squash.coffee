fs     = require 'fs'
path   = require 'path'
uglify = require 'uglify-js'

class exports.Squash
  options:
    compress:   false
    extensions: {}
    file:       null
    requires:   []
  
  extensions:
    '.js': (x) -> fs.readFileSync x, 'utf8'
  
  constructor: (options = {}) ->
    @node_path = if process.env.NODE_PATH then process.env.NODE_PATH.split(/:|;/g) else []
    @cwd       = path.dirname module.parent.filename
    @ext       = null
    @cache     = {}
    @resolved  = []
    @ordered   = []
    
    for name, value of options
      @options[name] = value
    @extensions[ext] = callback for ext, callback of @options.extensions
  
  squash: ->
    @require path, @cwd for path in @options.requires
    
    output = '''
      ;(function() {;
        var resolve = {};
        var require = function(path) {
          if(resolve[path])
            return resolve[path];
          else
            throw new Error('could not find module ' + path);
        };
        var register = function(paths, callback) {
          var module  = {exports: {}}
          var exports = module.exports;
          callback.call(exports, module, exports, require);
          
          for(var i in paths)
            resolve[paths[i]] = module.exports;
        };
        this.exports = resolve;
        this.require = require;
        
        
    '''
    for module in @ordered
      output += """
        ;register(['#{module.paths.join '\', \''}'], function(module, exports, require) {;
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
  
  require: (x, from) ->
    return if x in @resolved
    
    resolved = @resolve x, from
    if resolved of @cache
      @cache[resolved].paths.push x
      return
    
    js  = @extensions[@ext] resolved
    ast = uglify.parser.parse js
    
    from = path.dirname resolved
    @require dependency, from for dependency in @gather_dependencies ast
    
    @cache[resolved] = {resolved, js, paths: [x]}
    @resolved.push x
    @ordered.push @cache[resolved]
  
  gather_dependencies: (ast) ->
    dependencies = []
    walker = uglify.uglify.ast_walker()
    walker.with_walkers call: ([_, name], args) ->
      if name is 'require' and args.length and args[0][0] is 'string'
        dependencies.push args[0][1]
    , -> walker.walk(ast)
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