require('source-map-support').install()

{ expect } = require 'mocha'
assert = require 'assert'
Krate = require('../source').configure()

describe 'container components', ->
  container = null

  TIMEOUT = 200
  CUSTOM_TIMEOUT = 500

  beforeEach ->
    container = new Krate.Container({ timeout: TIMEOUT })
    container.define
      foo: -> 'foo'
      bar: -> Promise.resolve('bar')
      baz: (done) -> done(null, 'baz')
      qux: ({ resolve }) -> resolve('qux')

  describe 'defining', ->
    describe 'using an object', ->
      beforeEach ->
        container.define
          'define/object/factory': ->
            "define/object/factory"

        container.define
          'define/object/definition':
            factory: -> "define/object/definition"

        container.define 'define/string/factory', ->
          'define/string/factory'

        container.define 'define/string/definition',
          factory: -> 'define/string/definition'

        container.define 'define/string/depends/factory',
          ['foo'],
          ({ foo }) ->
            "define/string/depends/factory/#{foo}"


      it 'defines using a key and factory', ->
        container.resolve('define/object/factory as val').then ({ val }) ->
          assert.equal val, 'define/object/factory'

      it 'defines using a key and definition', ->
        container.resolve('define/object/definition as val').then ({ val }) ->
          assert.equal val, 'define/object/definition'

      it 'defines using a string and factory', ->
        container.resolve('define/string/factory as val').then ({ val }) ->
          assert.equal val, 'define/string/factory'

      it 'defines using a string, depends, and factory', ->
        container.resolve('define/string/depends/factory as val').then ({val}) ->
          assert.equal val, 'define/string/depends/factory/foo'

  describe 'factories', ->

    describe 'a factory returning a value', ->

      beforeEach ->
        container.define
          value: { factory: -> 'value' }

      it 'resolves to the value', ->
        container.resolve('value').then ({ value }) ->
          assert.equal value, 'value'

    describe 'a factory returning a promise', ->

      beforeEach ->
        container.define
          promise: { factory: -> Promise.resolve 'promise' }

      it 'resolve the promised value', ->
        container.resolve('promise').then ({ promise }) ->
          assert.equal promise, 'promise'

    describe 'an async factory using a callback', ->
      beforeEach ->
        container.define
          callback: { factory: (done) -> done null, 'callback' }

      it 'resolves using the callback', ->
        container.resolve('callback').then ({ callback }) ->
          assert.equal callback, 'callback'

    describe 'an async factory using a deferred', ->
      beforeEach ->
        container.define
          deferred: { factory: ({ resolve }) -> resolve 'deferred' }

      it 'resolves using the deferred', ->
        container.resolve('deferred').then ({ deferred }) ->
          assert.equal deferred, 'deferred'

    describe 'a sync factory throwing an error', ->

      beforeEach ->
        container.define "error/sync": { factory: -> throw Error("sync") }

      it "rejects with the error", ->
        container.resolve('error/sync').then null, (error) ->
          assert.equal error.message, "sync"

    describe 'a sync factory rejecting with an error', ->
      beforeEach ->
        container.define "error/reject": { factory: -> Promise.reject(Error("reject")) }

      it "rejects with the error", ->
        container.resolve('error/reject').then null, (error) ->
          assert.equal error.message, "reject"

    describe 'an async factory calling back with an error', ->
      beforeEach ->
        container.define 'error/callback': { factory: (done) -> done Error('callback') }

      it 'rejects with the error', ->
        container.resolve('error/callback').then null, (error) ->
          assert.equal error.message, 'callback'

    describe 'an async factory deferring with an error', ->
      beforeEach ->
        container.define 'error/deferred': { factory: ({ reject }) -> reject Error('deferred') }

      it 'rejects with the error', ->
        container.resolve('error/deferred').then null, (error) ->
          assert.equal error.message, 'deferred'

    describe 'an async factory throwing an error', ->

      beforeEach ->
        container.define 'error/async': { factory: (done) -> throw Error('async') }

      it 'rejects with the error', ->
        container.resolve('error/async').then null, (error) ->
          assert.equal error.message, 'async'

  describe 'dependencies', ->

    describe 'a string', ->
      beforeEach ->
        container.define 'deps/string':
          depends: 'foo'
          factory: ({ foo }) ->
            assert.equal foo, 'foo'

      it 'resolves using the key', ->
        container.resolve 'deps/string'

    describe 'a string with an alias', ->
      beforeEach ->
        container.define 'deps/string/alias':
          depends: 'foo as f'
          factory: ({ f }) ->
            assert.equal f, 'foo'
      it 'resolves using the alias', ->
        container.resolve 'deps/string/alias'

    describe 'an array of strings', ->
      beforeEach ->
        container.define 'deps/array',
          depends: ['foo as f', 'bar', 'baz', 'qux as q']
          factory: (vals) -> vals

      it 'resolves each string', ->
        container.resolve('deps/array as vals').then ({ vals }) ->
          { f, bar, baz, q } = vals
          assert.equal f, 'foo'
          assert.equal bar, 'bar'
          assert.equal baz, 'baz'
          assert.equal q, 'qux'

    describe 'a dependency map', ->

      beforeEach ->
        container.define
          'deps/object':
            factory: (vals) -> vals
            depends:
              f: 'foo'
              bar: null
              baz: true
              q: 'qux'

      it 'resolves keys as aliases', ->
        container.resolve('deps/object as vals').then ({ vals }) ->
          { f, bar, baz, q } = vals
          assert.equal f, 'foo'
          assert.equal bar, 'bar'
          assert.equal baz, 'baz'
          assert.equal q, 'qux'

    describe 'a reducer function', ->

      beforeEach ->
        container.define
          'deps/reducer':
            factory: (vals) -> vals
            depends: (memo, key, i) ->
              return memo unless /^b/.test(key)
              return memo.concat "#{key} as #{key}_alias"

      it 'uses the reducer to create the depends', ->
        container.resolve('deps/reducer as vals').then ({ vals }) ->
          { bar_alias, baz_alias } = vals
          assert.equal Object.keys(vals).length, 2
          assert.equal bar_alias, 'bar'
          assert.equal baz_alias, 'baz'

  describe 'overrides', ->

    beforeEach ->
      container.define 'foobar',
        depends: ['foo', 'bar']
        factory: ({ foo, bar }) -> foo + bar

    it 'can override depends', ->
      container.override 'foobar':
        depends: ['bar as foo', 'baz as bar']

      container.resolve('foobar').then ({ foobar }) ->
        assert.equal foobar, 'barbaz'

    it 'can override factories', ->
      container.override 'foobar':
        factory: ({ foo, bar }) -> bar + foo

      container.resolve('foobar').then ({ foobar }) ->
        assert.equal foobar, 'barfoo'

  describe 'timeouts', ->

    beforeEach ->
      container.define 'timeout/should',
        factory: ({resolve}) -> setTimeout resolve, TIMEOUT + 10

      container.define 'timeout/shouldnt',
        factory: ({resolve}) -> setTimeout resolve, TIMEOUT - 10

      container.define 'timeout/custom/should',
        timeout: CUSTOM_TIMEOUT
        factory: ({resolve}) -> setTimeout resolve, CUSTOM_TIMEOUT + 10

      container.define 'timeout/custom/shouldnt',
        timeout: CUSTOM_TIMEOUT
        factory: ({resolve}) -> setTimeout resolve, CUSTOM_TIMEOUT - 10

    it 'throws when components reach timeout', ->
      container.resolve('timeout/should').then null, (error) ->
        assert.equal 'ComponentTimedOut', error.name
        assert.equal 'timeout/should', error.payload.key

    it 'doesnt throw when components dont reach timeout', ->
      container.resolve('timeout/shouldnt')

    it 'throws when custom timeout reached', ->
      container.resolve('timeout/custom/should').then null, (error) ->
        assert.equal 'ComponentTimedOut', error.name
        assert.equal 'timeout/custom/should', error.payload.key

    it 'doesnt throw when custom timeout reached', ->
      container.resolve('timeout/custom/shouldnt')

  describe 'errors', ->

    beforeEach ->
      container.define 'cyclic', 'cyclic/a', -> null
      container.define 'cyclic/a', 'cyclic/b', -> null
      container.define 'cyclic/b', 'cyclic', -> null
      container.define 'depends/missing', 'missing', -> null
      container.define 'factory/invalid/0', [], (a, b) ->
      container.define 'factory/invalid/1', ['foo'], ->
      container.define 'factory/invalid/2', ['foo'], (a, b, c) ->

    it 'throws on dependency cycles', ->
      container.resolve('cyclic').then null, (error) ->
        assert.equal error.name, 'ComponentHasCircularDependency'

    it 'throws on undefined dependencies', ->
      container.resolve('depends/missing').then null, (error) ->
        assert.equal error.name, 'ComponentDependencyNotDefined'

    it 'throws on undefined components', ->
      container.resolve('missing').then null, (error) ->
        assert.equal error.name, 'ComponentNotDefined'

    it 'throws when factory takes 2, without depends', ->
      container.resolve('factory/invalid/0').then null, (error) ->
        assert.equal error.name, 'FactoryNotValid'

    it 'throws when factory takes 0, with depends', ->
      container.resolve('factory/invalid/1').then null, (error) ->
        assert.equal error.name, 'FactoryNotValid'

    it 'throws when factory takes 3, with depends', ->
      container.resolve('factory/invalid/1').then null, (error) ->
        assert.equal error.name, 'FactoryNotValid'
