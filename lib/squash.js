(function() {
  var fs, path, uglify;
  var __hasProp = Object.prototype.hasOwnProperty, __indexOf = Array.prototype.indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (__hasProp.call(this, i) && this[i] === item) return i; } return -1; };

  fs = require('fs');

  path = require('path');

  uglify = require('uglify-js');

  exports.Squash = (function() {

    Squash.prototype.options = {
      compress: false,
      extensions: {},
      file: null,
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
      this.node_path = process.env.NODE_PATH ? process.env.NODE_PATH.split(/:|;/g) : [];
      this.cwd = path.dirname(module.parent.filename);
      this.ext = null;
      this.cache = {};
      this.resolved = [];
      this.ordered = [];
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
      var ast, module, output, path, _i, _j, _len, _len2, _ref, _ref2;
      _ref = this.options.requires;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        path = _ref[_i];
        this.require(path, this.cwd);
      }
      output = ';(function() {;\n  var resolve = {};\n  var require = function(path) {\n    if(resolve[path])\n      return resolve[path];\n    else\n      throw new Error(\'could not find module \' + path);\n  };\n  var register = function(paths, callback) {\n    var module  = {exports: {}}\n    var exports = module.exports;\n    callback.call(exports, module, exports, require);\n    \n    for(var i in paths)\n      resolve[paths[i]] = module.exports;\n  };\n  this.exports = resolve;\n  this.require = require;\n  \n  ';
      _ref2 = this.ordered;
      for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
        module = _ref2[_j];
        output += ";register(['" + (module.paths.join('\', \'')) + "'], function(module, exports, require) {;\n  " + module.js + "\n;});\n";
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

    Squash.prototype.require = function(x, from) {
      var ast, dependency, js, resolved, _i, _len, _ref;
      if (__indexOf.call(this.resolved, x) >= 0) return;
      resolved = this.resolve(x, from);
      if (resolved in this.cache) {
        this.cache[resolved].paths.push(x);
        return;
      }
      js = this.extensions[this.ext](resolved);
      ast = uglify.parser.parse(js);
      from = path.dirname(resolved);
      _ref = this.gather_dependencies(ast);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        dependency = _ref[_i];
        this.require(dependency, from);
      }
      this.cache[resolved] = {
        resolved: resolved,
        js: js,
        paths: [x]
      };
      this.resolved.push(x);
      return this.ordered.push(this.cache[resolved]);
    };

    Squash.prototype.gather_dependencies = function(ast) {
      var dependencies, walker;
      dependencies = [];
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

    Squash.prototype.resolve = function(x, from) {
      var resolved, y;
      y = path.resolve(from, x);
      if (x.slice(0, 1) === '/' || x.slice(0, 2) === './' || x.slice(0, 3) === '../') {
        if (resolved = this.load_as_file(y)) return resolved;
        if (resolved = this.load_as_directory(y)) return resolved;
      }
      if (resolved = this.load_node_module(x)) return resolved;
      throw new Error("could not find module " + x);
    };

    Squash.prototype.load_as_file = function(x) {
      var ext, y;
      if (path.existsSync(x) && fs.statSync(x).isFile()) {
        this.ext = x.slice(x.lastIndexOf('.')) || '.js';
        return x;
      }
      for (ext in this.extensions) {
        if (path.existsSync((y = x + (this.ext = ext)))) return y;
      }
      return false;
    };

    Squash.prototype.load_as_directory = function(x) {
      var ext, package, y;
      if (path.existsSync((y = x + '/package.json'))) {
        package = JSON.parse(fs.readFileSync(y, 'utf8'));
        if (package.main) return this.load_as_file(path.resolve(x, package.main));
      }
      for (ext in this.extensions) {
        if (path.existsSync((y = x + '/index' + (this.ext = ext)))) return y;
      }
      return false;
    };

    Squash.prototype.load_node_module = function(x) {
      var dir, resolved, _i, _len, _ref;
      _ref = this.node_modules_dirs().concat(this.node_path);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        dir = _ref[_i];
        if (resolved = this.load_as_file(path.join(dir, x))) return resolved;
        if (resolved = this.load_as_directory(path.join(dir, x))) return resolved;
      }
      return false;
    };

    Squash.prototype.node_modules_dirs = function() {
      var dirs, i, parts, root;
      parts = this.cwd.split(/\\|\//g);
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
