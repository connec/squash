{Squash} = require '../squash'

describe 'squash', ->
  
  it 'should produce the boilerplate when no inputs are given', ->
    squash = new Squash
    expect(squash.squash()).toEqual '''
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
        
        
      ;}).call(this);
    '''
  
  it 'should produce code that defines exports and require in the given context', ->
    squash  = new Squash
    context = {}
    (new Function squash.squash()).call context
    
    expect(context.exports).toEqual {}
    expect(typeof context.require).toEqual 'function'
  
  it 'should throw an error if something is required that does not exist', ->
    squash  = new Squash
    context = {}
    (new Function squash.squash()).call context
    
    expect(-> (new Squash requires: ['non-existant']).squash()).toThrow 'could not find module non-existant'
    expect(-> context.require 'non-existant').toThrow 'could not find module non-existant'
  
  it 'should pick up assignments to `module.exports` for given entry requires', ->
    squash  = new Squash requires: ['./test/requires/a']
    context = {}
    (new Function squash.squash()).call context
    
    expect(context.exports['./test/requires/a']).toEqual {a: 'a'}
    expect(context.require('./test/requires/a')).toEqual {a: 'a'}
  
  it 'should detect dependencies in entry requires and catalogue their exports as well', ->
    squash  = new Squash requires: ['./test/requires/b']
    context = {}
    (new Function squash.squash()).call context
    
    expect(context.exports['./a']).toEqual {a: 'a'}
    expect(context.require('./a')).toEqual {a: 'a'}
    
    expect(context.exports['./test/requires/b']).toEqual {a: 'a', b: 'b'}
    expect(context.require('./test/requires/b')).toEqual {a: 'a', b: 'b'}