(function() {
  var fs, path, uglify, util,
    __indexOf = Array.prototype.indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  fs = require('fs');

  path = require('path');

  uglify = require('uglify-js');

  util = require('util');

  exports.Squash = (function() {

    function Squash(options) {
      var callback, ext, key, value, _ref;
      if (options == null) options = {};
      this.node_path = process.env.NODE_PATH ? process.env.NODE_PATH.split((__indexOf.call(process.env.NODE_PATH, '\\') >= 0 ? /;/g : /:/g)) : [];
      this.ext = null;
      this.modules = {};
      this.ordered = [];
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
      this.extensions = {
        '.js': function(x) {
          return fs.readFileSync(x, 'utf8');
        }
      };
      _ref = this.options.extensions;
      for (ext in _ref) {
        callback = _ref[ext];
        this.extensions[ext] = callback;
      }
    }

    Squash.prototype.watch = function(callback) {
      var update_watchers, watchers,
        _this = this;
      watchers = {};
      update_watchers = function() {
        var file, new_watchers, watcher, _fn, _i, _len, _ref;
        new_watchers = {};
        _ref = _this.ordered;
        _fn = function(file) {
          var skip;
          skip = false;
          return new_watchers[file] = fs.watch(file, function(event, filename) {
            if (filename == null) filename = file;
            if (skip) return;
            skip = true;
            return setTimeout(function() {
              var result;
              skip = false;
              _this.modules = {};
              _this.ordered = [];
              try {
                result = _this.squash();
                update_watchers();
                return callback(null, result);
              } catch (error) {
                return callback(error);
              }
            }, 25);
          });
        };
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          file = _ref[_i];
          if (file in watchers) {
            new_watchers[file] = watchers[file];
            continue;
          }
          _fn(file);
        }
        for (file in watchers) {
          watcher = watchers[file];
          if (!(file in new_watchers)) watcher.close();
        }
        return watchers = new_watchers;
      };
      callback(null, this.squash());
      return update_watchers();
    };

    Squash.prototype.squash = function() {
      var alias, ast, directory, file, id, module, names, obfuscate, obfuscated, output, path, _, _i, _len, _ref, _ref2, _ref3;
      for (path in this.options.requires) {
        this.require(path, this.options.cwd);
      }
      output = "(function() {\n  var root = this, modules, require_from, register, error;\n  if(typeof global == 'undefined') {\n    var global;\n    if(typeof window != 'undefined') {\n      global = window;\n    } else {\n      global = {};\n    }\n  }\n  modules = {};\n  require_from = function(from) {\n    return (function(name) {\n      if(modules[from] && modules[from][name]) {\n        if(modules[from][name].initialize) {\n          modules[from][name].initialize();\n        }\n        return modules[from][name].exports;\n      } else {\n        return error(name, from);\n      }\n    });\n  };\n  register = function(names, directory, callback) {\n    var module  = {\n      exports: {},\n      initialize: function() {\n        callback.call(module.exports, global, module, module.exports, require_from(directory), undefined);\n        delete module.initialize;\n      }\n    };\n    for(var from in names) {\n      modules[from] = modules[from] || {};\n      for(var j in names[from]) {\n        var name = names[from][j];\n        modules[from][name] = module;\n      }\n    }\n  };\n  error = ";
      if (this.options.relax) {
        if (typeof this.options.relax === 'function') {
          output += "" + (String(this.options.relax)) + ";";
        } else {
          output += 'function() { return null; };\n';
        }
      } else {
        output += 'function(name, from) { throw new Error(\'could not find module \' + name); };\n';
      }
      obfuscated = {
        '': ''
      };
      id = 0;
      obfuscate = function(names) {
        var from, result, _ref;
        result = {};
        for (from in names) {
          result[(_ref = obfuscated[from]) != null ? _ref : obfuscated[from] = id++] = names[from];
        }
        return result;
      };
      _ref = this.ordered;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        file = _ref[_i];
        module = this.modules[file];
        directory = module.directory, names = module.names;
        if (this.options.obfuscate) {
          directory = ((_ref2 = obfuscated[directory]) != null ? _ref2 : obfuscated[directory] = id++);
          names = obfuscate(names);
        }
        output += "\nregister(" + (util.inspect(names)) + ", " + (util.inspect(directory)) + ", function(global, module, exports, require, window) {\n  " + module.js + "\n});\n";
      }
      _ref3 = this.options.requires;
      for (_ in _ref3) {
        alias = _ref3[_];
        output += "root['" + alias + "'] = require_from('')('" + alias + "');\n";
      }
      output += '\n;}).call(this);';
      ast = uglify.parser.parse(output);
      if (this.options.compress) {
        ast = uglify.uglify.ast_squeeze(uglify.uglify.ast_mangle(ast));
        output = uglify.uglify.gen_code(ast);
      } else {
        output = uglify.uglify.gen_code(ast, {
          beautify: true
        });
      }
      return output;
    };

    Squash.prototype.require = function(name, from) {
      var dependency, file, names, _base, _i, _len, _name, _ref, _ref2;
      try {
        file = this.resolve(name, from);
      } catch (error) {
        if (this.options.relax) {
          if (typeof this.options.relax === 'function') {
            this.options.relax(name, from);
          }
          return;
        }
        throw error;
      }
      if (this.modules[file] != null) {
        names = ((_ref = (_base = this.modules[file].names)[_name = path.relative(this.options.cwd, from)]) != null ? _ref : _base[_name] = []);
        if (__indexOf.call(names, name) < 0) names.push(name);
        return;
      }
      this.modules[file] = {
        directory: path.relative(this.options.cwd, path.dirname(file)),
        js: this.extensions[this.ext](file),
        names: {}
      };
      if (from === this.options.cwd && name in this.options.requires) {
        name = this.options.requires[name];
      }
      this.modules[file].names[path.relative(this.options.cwd, from)] = [name];
      _ref2 = this.gather_dependencies(file);
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        dependency = _ref2[_i];
        this.require(dependency, path.dirname(file));
      }
      return this.ordered.push(file);
    };

    Squash.prototype.gather_dependencies = function(file) {
      var ast, dependencies, walker;
      dependencies = [];
      ast = uglify.parser.parse(this.modules[file].js);
      walker = uglify.uglify.ast_walker();
      walker.with_walkers({
        call: function(_arg, args) {
          var name, _;
          _ = _arg[0], name = _arg[1];
          if (name === 'require' && args.length && args[0][0] === 'string') {
            return dependencies.push(args[0][1]);
          }
        }
      }, function() {
        return walker.walk(ast);
      });
      return dependencies;
    };

    Squash.prototype.resolve = function(name, from) {
      var file, resolved;
      file = path.resolve(from, name);
      if (name.slice(0, 1) === '/' || name.slice(0, 2) === './' || name.slice(0, 3) === '../') {
        if (resolved = this.load_as_file(file)) return resolved;
        if (resolved = this.load_as_directory(file)) return resolved;
      }
      if (resolved = this.load_node_module(name, from)) return resolved;
      throw new Error("could not find module " + name);
    };

    Squash.prototype.load_as_file = function(file) {
      var ext, resolved;
      if (path.existsSync(file) && fs.statSync(file).isFile()) {
        this.ext = file.slice(file.lastIndexOf('.')) || '.js';
        return file;
      }
      for (ext in this.extensions) {
        if (path.existsSync((resolved = file + (this.ext = ext)))) return resolved;
      }
      return false;
    };

    Squash.prototype.load_as_directory = function(dir) {
      var ext, name, package, resolved;
      if (path.existsSync((package = path.resolve(dir, 'package.json')))) {
        package = JSON.parse(fs.readFileSync(package, 'utf8'));
        if (package.main) {
          name = path.resolve(dir, package.main);
          if (resolved = this.load_as_file(name)) return resolved;
          if (resolved = this.load_as_directory(name)) return resolved;
        }
      }
      for (ext in this.extensions) {
        if (path.existsSync((resolved = path.resolve(dir, 'index' + (this.ext = ext))))) {
          return resolved;
        }
      }
      return false;
    };

    Squash.prototype.load_node_module = function(module, from) {
      var dir, resolved, _i, _len, _ref;
      _ref = this.node_modules_dirs(from).concat(this.node_path);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        dir = _ref[_i];
        if (resolved = this.load_as_file(path.join(dir, module))) return resolved;
        if (resolved = this.load_as_directory(path.join(dir, module))) {
          return resolved;
        }
      }
      return false;
    };

    Squash.prototype.node_modules_dirs = function(from) {
      var dirs, i, parts, root;
      parts = from.split(/\\|\//g);
      root = (i = parts.indexOf('node_modules')) !== -1 ? i : 0;
      i = parts.length - 1;
      dirs = [];
      for (i = i; i <= root ? i < root : i > root; i <= root ? i++ : i--) {
        if (parts[i] === 'node_modules') continue;
        dirs.push(path.join.apply(path, parts.slice(0, i + 1 || 9e9).concat(['node_modules'])));
      }
      return dirs;
    };

    return Squash;

  })();

}).call(this);
