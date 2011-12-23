(function() {
  var fs, path, uglify, util;
  var __hasProp = Object.prototype.hasOwnProperty, __indexOf = Array.prototype.indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (__hasProp.call(this, i) && this[i] === item) return i; } return -1; };

  fs = require('fs');

  path = require('path');

  uglify = require('uglify-js');

  util = require('util');

  exports.Squash = (function() {

    Squash.prototype.node_path = process.env.NODE_PATH ? process.env.NODE_PATH.split(/:|;/g) : [];

    Squash.prototype.cwd = null;

    Squash.prototype.ext = null;

    Squash.prototype.modules = {};

    Squash.prototype.ordered = [];

    Squash.prototype.options = {
      compress: false,
      extensions: {},
      requires: []
    };

    Squash.prototype.extensions = {
      '.js': function(x) {
        return fs.readFileSync(x, 'utf8');
      }
    };

    function Squash(options) {
      var callback, ext, name, value, _ref;
      if (options == null) options = {};
      this.cwd = path.dirname(module.parent.filename);
      for (name in options) {
        value = options[name];
        this.options[name] = value;
      }
      _ref = this.options.extensions;
      for (ext in _ref) {
        callback = _ref[ext];
        this.extensions[ext] = callback;
      }
    }

    Squash.prototype.squash = function() {
      var ast, file, module, output, path, _i, _j, _len, _len2, _ref, _ref2;
      _ref = this.options.requires;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        path = _ref[_i];
        this.require(path, this.cwd);
      }
      output = ";(function() {;\n  var modules = {};\n  var require_from = function(from) {\n    return (function(name) {\n      if(modules[from] && modules[from][name]) {\n        return modules[from][name];\n      } else {\n        throw new Error('could not find module ' + name);\n      }\n    });\n  };\n  var register = function(names, directory, callback) {\n    var module  = {exports: {}};\n    var exports = module.exports;\n    callback.call(exports, module, exports, require_from(directory));\n    \n    for(var from in names) {\n      modules[from] = modules[from] || {};\n      for(var j in names[from]) {\n        var name = names[from][j];\n        modules[from] = modules[from] || {};\n        modules[from][name] = module.exports;\n      }\n    }\n  };\n  this.exports = modules;\n  this.require = require_from(" + (util.inspect(this.cwd)) + ");";
      _ref2 = this.ordered;
      for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
        file = _ref2[_j];
        module = this.modules[file];
        output += ";register(" + (util.inspect(module.names)) + ", " + (util.inspect(module.directory)) + ", function(module, exports, require) {;\n  " + module.js + "\n;});";
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
      var dependency, file, names, _base, _i, _len, _ref, _ref2;
      file = this.resolve(name, from);
      if (this.modules[file] != null) {
        names = ((_ref = (_base = this.modules[file].names)[from]) != null ? _ref : _base[from] = []);
        if (__indexOf.call(names, name) < 0) names.push(name);
        return;
      }
      this.modules[file] = {
        directory: path.dirname(file),
        js: fs.readFileSync(file, 'utf8'),
        names: {}
      };
      this.modules[file].names[from] = [name];
      _ref2 = this.gather_dependencies(file);
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        dependency = _ref2[_i];
        this.require(dependency, this.modules[file].directory);
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
      var ext, package, resolved;
      if (path.existsSync((package = path.resolve(dir, 'package.json')))) {
        package = JSON.parse(fs.readFileSync(package, 'utf8'));
        if (package.main) {
          return this.load_as_file(path.resolve(dir, package.main));
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
