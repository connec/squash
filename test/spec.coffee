{Squash} = require '../lib/squash'
util     = require 'util'

describe 'squash', ->

  it 'should produce the boilerplate when no inputs are given', ->
    squash = new Squash
    result = squash.squash()

    expect(typeof result).to.be.a 'string'
    expect(result).to.be.ok

    context = {}
    (new Function result).call context

    expect(context).to.deep.equal {}

  it 'should throw an error if something is required that does not exist', ->
    squash = new Squash requires: {'non-existant'}
    expect( -> squash.squash() ).to.throw 'could not find module non-existant'

  it 'should ignore non-existant requires during compilation if the relax flag is set', ->
    squash = new Squash relax: (-> return 'error'), requires: {'non-existant'}
    result = squash.squash()

    expect(result).to.be.a 'string'
    expect(result).to.be.ok

    context = {}
    (new Function result).call context

    expect(context).to.deep.equal { 'non-existant': 'error' }

  it 'should pick up assignments to `module.exports` for given entry requires', ->
    squash  = new Squash requires: {'./requires/a'}
    context = {}
    (new Function squash.squash()).call context

    expect(context).to.deep.equal { './requires/a': { a: 'a' } }

  it 'should assign the alias to the context object if one is given', ->
    squash  = new Squash requires: {'./requires/a': 'a'}
    context = {}
    (new Function squash.squash()).call context

    expect(context).to.deep.equal { a: { a: 'a' } }

  it 'should detect dependencies in entry requires and catalogue their exports as well', ->
    squash  = new Squash requires: {'./requires/b'}
    context = {}
    (new Function squash.squash()).call context

    expect(context).to.deep.equal { './requires/b': { a: 'a', b: 'b' } }

  it 'should compress output when the compress flag is set, and this should not effect the result', ->
    squash = new Squash requires: {'./requires/a'}
    code1  = squash.squash()
    squash = new Squash compress: true, requires: {'./requires/a'}
    code2  = squash.squash()

    expect(code1).to.have.length.above code2.length

    context1 = {}
    (new Function code1).call context1

    context2 = {}
    (new Function code2).call context2

    expect(context1).to.deep.equal context2

  it 'should be able to locate and embed node modules', ->
    squash  = new Squash requires: {'./requires/c'}
    context = {}
    (new Function squash.squash()).call context

    expect(context).to.deep.equal { './requires/c': { c: 'c', d: 'd' } }

  it 'should obfuscate directories when obfuscate option is true', ->
    squash  = new Squash requires: {'./requires/b'}
    result  = squash.squash()
    context = {}
    (new Function result).call context

    expect(result).to.match /register\(\s*\{\s*("|')?requires\1\s*:\s*\[\s*("|')\.\/a\2\s*\]\s*\}/
    expect(context).to.deep.equal { './requires/b': { a: 'a', b: 'b' } }

    squash  = new Squash obfuscate: true, requires: {'./requires/b'}
    result  = squash.squash()
    context = {}
    (new Function result).call context

    expect(result).to.match /register\(\s*\{\s*("|')?(?!requires).+\1\s*:\s*\[\s*("|')\.\/a\2\s*\]\s*\}/
    expect(context).to.deep.equal { './requires/b': { a: 'a', b: 'b' } }

  it 'should suppress `window` in scripts for the purpose of compatibility checks', ->
    squash  = new Squash requires: {'./requires/e'}
    context = {}

    # We need eval here so that window is in-scope
    window = {}
    eval("(function() {" + squash.squash() + "})").call context

    expect(context).to.deep.equal { './requires/e': { env: 'commonjs' } }

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

    # Resort to util.inspect here because chai cannot handle circular references
    inspect = (o) -> util.inspect o, false, null
    expect(inspect context).to.equal inspect expected