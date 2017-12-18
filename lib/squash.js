(function() {
  var fs, getDependency, path, uglify, util,
    indexOf = [].indexOf;

  fs = require('fs');

  path = require('path');

  uglify = require('uglify-es');

  util = require('util');

  exports.Squash = class Squash {
    // Initialize a new instance with given options
    constructor(options = {}) {
      var callback, ext, key, ref, value;
      // Directories to search for node_modules
      this.node_path = process.env.NODE_PATH ? process.env.NODE_PATH.split((indexOf.call(process.env.NODE_PATH, '\\') >= 0 ? /;/g : /:/g)) : [];
      // The extension of the last resolved file
      this.ext = null;
      // The details of all the discovered modules
      this.modules = {};
      // Contains the module file names in the order they should be output
      this.ordered = [];
      // Set up the options
      this.options = {
        compress: false,
        cwd: path.dirname(module.parent.filename),
        extensions: {},
        obfuscate: false,
        relax: false,
        requires: {}
      };
      for (key in options) {
        value = options[key];
        this.options[key] = value;
      }
      // Set up the extensions
      this.extensions = {
        '.js': function(x) {
          return fs.readFileSync(x, 'utf8');
        }
      };
      ref = this.options.extensions;
      for (ext in ref) {
        callback = ref[ext];
        this.extensions[ext] = callback;
      }
    }

    // Watch the initial requires and their dependencies for changes and execute
    // the callback with the reconstructed script.
    watch(callback) {
      var update_watchers, watchers;
      // Remember which files we are watching
      watchers = {};
      // Updates the watchers list based on the filenames discovered with the last
      // `@squash` operation
      update_watchers = () => {
        var file, fn, j, len, new_watchers, ref, watcher;
        new_watchers = {};
        ref = this.ordered;
        // Otherwise create a watcher for the file
        fn = (file) => { // We use `do` to create a `skip` flag for each file
          var skip;
          skip = false;
          return new_watchers[file] = fs.watch(file, (event, filename = file) => {
            if (skip) {
              return;
            }
            skip = true;
            // Update after a short delay to ensure the file is available for
            // reading, and to ignore duplicate events
            return setTimeout(() => {
              var error, result;
              skip = false;
              this.modules = {};
              this.ordered = [];
              try {
                result = this.squash();
                update_watchers();
                return callback(null, result);
              } catch (error1) {
                error = error1;
                return callback(error);
              }
            }, 25);
          });
        };
        for (j = 0, len = ref.length; j < len; j++) {
          file = ref[j];
          if (file in watchers) {
            // If the file is already being watched just copy the watcher
            new_watchers[file] = watchers[file];
            continue;
          }
          fn(file);
        }
        // Clear the watchers for any file no longer in the dependency tree
        for (file in watchers) {
          watcher = watchers[file];
          if (!(file in new_watchers)) {
            watcher.close();
          }
        }
        return watchers = new_watchers;
      };
      // Start the first round of watchers
      callback(null, this.squash());
      return update_watchers();
    }

    // Produce a script combining the initial requires and all their dependencies
    squash() {
      var _, _path, alias, directory, file, id, j, len, module, names, obfuscate, obfuscated, output, ref, ref1;
      for (_path in this.options.requires) {
        // Require the initial dependencies
        this.require(_path, this.options.cwd);
      }
      // Build the initial boilerplate
      output = "(function() {\n  var root = this, modules, require_from, register, error;\n  if(typeof global == 'undefined') {\n    var global = typeof window === 'undefined' ? root : window;\n  }\n  modules = {};\n  require_from = function(parent, from) {\n    return (function(name) {\n      if(modules[from] && modules[from][name]) {\n        modules[from][name].parent = parent;\n        if(modules[from][name].initialize) {\n          modules[from][name].initialize();\n        }\n        return modules[from][name].exports;\n      } else {\n        return error(name, from);\n      }\n    });\n  };\n  register = function(names, directory, callback) {\n    var module  = {\n      exports: {},\n      initialize: function() {\n        callback.call(module.exports, global, module, module.exports, require_from(module, directory), undefined);\n        delete module.initialize;\n      },\n      parent: null\n    };\n    for(var from in names) {\n      modules[from] = modules[from] || {};\n      for(var j in names[from]) {\n        var name = names[from][j];\n        modules[from][name] = module;\n      }\n    }\n  };\n  error =";
      if (this.options.relax) {
        if (typeof this.options.relax === 'function') {
          output += `${String(this.options.relax)};`;
        } else {
          output += 'function() { return null; };\n';
        }
      } else {
        output += 'function(name, from) { throw new Error(\'could not find module \' + name); };\n';
      }
      // Machinery for obfuscating paths
      obfuscated = {
        '': ''
      };
      id = 0;
      obfuscate = function(names) {
        var from, result;
        result = {};
        for (from in names) {
          result[obfuscated[from] != null ? obfuscated[from] : obfuscated[from] = id++] = names[from];
        }
        return result;
      };
      ref = this.ordered;
      for (j = 0, len = ref.length; j < len; j++) {
        file = ref[j];
        module = this.modules[file];
        // Obfuscate the paths if the option is set
        ({directory, names} = module);
        if (this.options.obfuscate) {
          directory = (obfuscated[directory] != null ? obfuscated[directory] : obfuscated[directory] = id++);
          names = obfuscate(names);
        }
        // Add the code to register the module
        output += `\nregister(${util.inspect(names)}, ${util.inspect(directory)}, function(global, module, exports, require, window) {\n  ${module.js}\n});\n`;
      }
      ref1 = this.options.requires;
      // Add the code to register the initial requires on the root object
      for (_ in ref1) {
        alias = ref1[_];
        output += `root['${alias}'] = require_from(null, '')('${alias}');\n`;
      }
      output += '\n;}).call(this);';
      // Beautify or compress the output
      output = uglify.minify(output, {
        compress: this.options.compress,
        mangle: false,
        output: {
          beautify: !this.options.compress
        }
      });
      return output.code;
    }

    // Load the details of the given module and recurse for its dependencies
    require(name, from) {
      var base, dependency, error, file, j, len, name1, names, ref;
      try {
        // Resolve `path` to a source file, treating `path` as relative to `from`
        file = this.resolve(name, from);
      } catch (error1) {
        error = error1;
        // If we're 'relaxed', just warn about the missing dependency
        if (this.options.relax) {
          if (typeof this.options.relax === 'function') {
            this.options.relax(name, from);
          }
          return;
        }
        throw error;
      }
      // If this module has already been required, register the path and move on
      if (this.modules[file] != null) {
        names = ((base = this.modules[file].names)[name1 = path.relative(this.options.cwd, from)] != null ? base[name1] : base[name1] = []);
        if (indexOf.call(names, name) < 0) {
          names.push(name);
        }
        return;
      }
      // Register the source as a module
      this.modules[file] = {
        directory: path.relative(this.options.cwd, path.dirname(file)),
        js: this.extensions[this.ext](file),
        names: {}
      };
      if (from === this.options.cwd && name in this.options.requires) {
        name = this.options.requires[name];
      }
      this.modules[file].names[path.relative(this.options.cwd, from)] = [name];
      ref = this.gather_dependencies(file);
      for (j = 0, len = ref.length; j < len; j++) {
        dependency = ref[j];
        // Recurse for the module's dependencies
        this.require(dependency, path.dirname(file));
      }
      // Finally, register this module in its correct order
      return this.ordered.push(file);
    }

    // Find required dependencies using a walk of the AST
    gather_dependencies(file) {
      var ast, dependencies;
      dependencies = [];
      ({ast} = uglify.minify({
        [`${file}`]: this.modules[file].js
      }, {
        parse: {},
        compress: false,
        mangle: false,
        output: {
          ast: true,
          code: false
        }
      }));
      ast.walk(new uglify.TreeWalker(function(node) {
        var dependency;
        if (dependency = getDependency(node)) {
          return dependencies.push(dependency);
        }
      }));
      return dependencies;
    }

    // Attempts to resolve a module's file given the required string and a base location
    resolve(name, from) {
      var file, resolved;
      // Compute the absolute path
      file = path.resolve(from, name);
      // If it's a relative import...
      if (name.slice(0, 1) === '/' || name.slice(0, 2) === './' || name.slice(0, 3) === '../') {
        if (resolved = this.load_as_file(file)) {
          // Try to load it as a file
          return resolved;
        }
        if (resolved = this.load_as_directory(file)) {
          // Try to load it as a directory
          return resolved;
        }
      }
      if (resolved = this.load_node_module(name, from)) {
        // Otherwise, try to load it as a node module
        return resolved;
      }
      // If we reach here the module could not be found, throw an error
      throw new Error(`could not find module ${name}`);
    }

    // Attempt to load the given path as a file
    load_as_file(file) {
      var ext, resolved;
      if (fs.existsSync(file) && fs.statSync(file).isFile()) {
        // The path exists and is a file, return it unchanged
        this.ext = file.slice(file.lastIndexOf('.')) || '.js';
        return file;
      }
      // Try registered extensions
      for (ext in this.extensions) {
        if (fs.existsSync((resolved = file + ext))) {
          this.ext = ext;
          return resolved;
        }
      }
      return false;
    }

    // Attempt to load the given path as a directory
    load_as_directory(dir) {
      var ext, name, pkg, resolved;
      // Attempt to load the `main` attribute from package.json
      if (fs.existsSync((pkg = path.resolve(dir, 'package.json')))) {
        pkg = JSON.parse(fs.readFileSync(pkg, 'utf8'));
        if (pkg.main) {
          name = path.resolve(dir, pkg.main);
          if (resolved = this.load_as_file(name)) {
            return resolved;
          }
          if (resolved = this.load_as_directory(name)) {
            return resolved;
          }
        }
      }
      for (ext in this.extensions) {
        if (fs.existsSync((resolved = path.resolve(dir, 'index' + (this.ext = ext))))) {
          // Try registered extensions with an 'index' file
          return resolved;
        }
      }
      return false;
    }

    // Attempt to load the given path as a node module
    load_node_module(module, from) {
      var dir, j, len, ref, resolved;
      ref = this.node_modules_dirs(from).concat(this.node_path);
      for (j = 0, len = ref.length; j < len; j++) {
        dir = ref[j];
        if (resolved = this.load_as_file(path.join(dir, module))) {
          return resolved;
        }
        if (resolved = this.load_as_directory(path.join(dir, module))) {
          return resolved;
        }
      }
      return false;
    }

    // Generate an array of 'node_modules' paths for the current directory
    node_modules_dirs(from) {
      var dirs, i, j, parts, ref, ref1, root;
      parts = from.split(/\\|\//g);
      root = (i = parts.indexOf('node_modules')) !== -1 ? i : 0;
      i = parts.length - 1;
      dirs = [];
      for (i = j = ref = i, ref1 = root; ref <= ref1 ? j < ref1 : j > ref1; i = ref <= ref1 ? ++j : --j) {
        if (parts[i] === 'node_modules') {
          continue;
        }
        dirs.push(path.join.apply(path, parts.slice(0, +i + 1 || 9e9).concat(['node_modules'])));
      }
      return dirs;
    }

  };

  getDependency = function(node) {
    if (!(node instanceof uglify.AST_Call)) {
      return null;
    }
    if (!(node.expression instanceof uglify.AST_SymbolRef)) {
      return null;
    }
    if (node.expression.name !== 'require') {
      return null;
    }
    if (node.args.length !== 1) {
      return null;
    }
    if (!(node.args[0] instanceof uglify.AST_String)) {
      return null;
    }
    return node.args[0].value;
  };

}).call(this);
