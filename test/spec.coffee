{Squash} = require '../lib/squash'
util     = require 'util'

describe 'squash', ->
  
  it 'should produce the boilerplate when no inputs are given', ->
    squash = new Squash
    result = squash.squash()
    
    expect(typeof result).toEqual 'string'
    expect(result).toBeTruthy()
    
    context = {}
    (new Function result).call context
    
    expect(context).toEqual {}
  
  it 'should throw an error if something is required that does not exist', ->
    squash  = new Squash
    context = {}
    (new Function squash.squash()).call context
    
    expect(-> (new Squash requires: {'non-existant'}).squash()).toThrow 'could not find module non-existant'
    expect(context).toEqual {}
  
  it 'should ignore non-existant requires during compilation if the relax flag is set', ->
    squash = new Squash relax: (-> return 'error'), requires: {'non-existant'}
    result = squash.squash()
    
    expect(typeof result).toEqual 'string'
    expect(result).toBeTruthy()
    
    context = {}
    (new Function result).call context
    
    expect(context).toEqual {'non-existant': 'error'}
  
  it 'should pick up assignments to `module.exports` for given entry requires', ->
    squash  = new Squash requires: {'./requires/a'}
    context = {}
    (new Function squash.squash()).call context
    
    expect(context).toEqual {'./requires/a': {a: 'a'}}
  
  it 'should assign the alias to the context object if one is given', ->
    squash  = new Squash requires: {'./requires/a': 'a'}
    context = {}
    (new Function squash.squash()).call context
    
    expect(context).toEqual {a: {a: 'a'}}
  
  it 'should detect dependencies in entry requires and catalogue their exports as well', ->
    squash  = new Squash requires: {'./requires/b'}
    context = {}
    (new Function squash.squash()).call context
    
    expect(context).toEqual {'./requires/b': {a: 'a', b: 'b'}}
  
  it 'should not attach dependencies to the context object', ->
    squash  = new Squash requires: {'./requires/b'}
    context = {}
    (new Function squash.squash()).call context
    
    expect(context).toEqual {'./requires/b': {a: 'a', b: 'b'}}
  
  it 'should compress output when the compress flag is set, and this should not effect the result', ->
    squash = new Squash requires: {'./requires/a'}
    code1  = squash.squash()
    squash = new Squash compress: true, requires: {'./requires/a'}
    code2  = squash.squash()
    
    expect(code1.length).toBeGreaterThan code2.length
    
    context1 = {}
    (new Function code1).call context1
    
    context2 = {}
    (new Function code2).call context2
    
    expect(context1).toEqual context2
  
  it 'should be able to locate and embed node modules', ->
    squash  = new Squash requires: {'./requires/c'}
    context = {}
    (new Function squash.squash()).call context
    
    expect(context).toEqual {'./requires/c': {c: 'c', d: 'd'}}
  
  it 'should obfuscate directories when obfuscate option is true', ->
    squash  = new Squash requires: {'./requires/b'}
    result  = squash.squash()
    context = {}
    (new Function result).call context
    
    expect(result).toMatch /register\(\s*\{\s*("|')?requires\1\s*:\s*\[\s*("|')\.\/a\2\s*\]\s*\}/
    expect(context).toEqual {'./requires/b': {a: 'a', b: 'b'}}
    
    squash  = new Squash obfuscate: true, requires: {'./requires/b'}
    result  = squash.squash()
    context = {}
    (new Function result).call context
    
    expect(result).toMatch /register\(\s*\{\s*("|')?(?!requires).+\1\s*:\s*\[\s*("|')\.\/a\2\s*\]\s*\}/
    expect(context).toEqual {'./requires/b': {a: 'a', b: 'b'}}
  
  it 'should suppress `window` in scripts for the purpose of compatibility checks', ->
    squash  = new Squash requires: {'./requires/e'}
    context = {}
    
    # We need eval here so that window is in-scope
    window = {}
    eval "(function() { #{squash.squash()} }).call(context);"
    
    expect(context).toEqual {'./requires/e': {env: 'commonjs'}}
  
  it 'should expose the parent module', ->
    squash  = new Squash requires: {'./requires/g'}
    context = {}
    (new Function squash.squash()).call context
    
    expected =
      './requires/g':
        g: 'g'
        f:
          f: 'f'
    expected['./requires/g'].f.parent = expected['./requires/g']
    
    expect(context).toEqual expected