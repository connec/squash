{Squash} = require '../lib/squash'

describe 'squash', ->
  
  it 'should produce the boilerplate when no inputs are given', ->
    squash = new Squash
    expect(typeof squash.squash()).toEqual 'string'
    expect(squash.squash()).toBeTruthy()
  
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
    squash  = new Squash requires: ['./requires/a']
    context = {}
    (new Function squash.squash()).call context
    
    expect(context.exports['']['./requires/a']).toEqual {a: 'a'}
    expect(context.require './requires/a').toEqual {a: 'a'}
  
  it 'should detect dependencies in entry requires and catalogue their exports as well', ->
    squash  = new Squash requires: ['./requires/b']
    context = {}
    (new Function squash.squash()).call context
    
    expect(context.exports['requires']['./a']).toEqual {a: 'a'}
    
    expect(context.exports['']['./requires/b']).toEqual {a: 'a', b: 'b'}
    expect(context.require './requires/b').toEqual {a: 'a', b: 'b'}
  
  it 'should compress output when the compress flag is set, but this should not effect the result', ->
    squash1  = new Squash requires: ['./requires/a']
    context1 = {}
    (new Function squash1.squash()).call context1
    
    squash2  = new Squash compress: true, requires: ['./requires/a']
    context2 = {}
    (new Function squash2.squash()).call context2
    
    expect(context1.require './requires/a').toEqual context2.require './requires/a'
  
  it 'should be able to locate and embed node modules', ->
    squash  = new Squash requires: ['./requires/c']
    context = {}
    (new Function squash.squash()).call context
    
    expect(context.require './requires/c').toEqual {c: 'c', d: 'd'}