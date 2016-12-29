class Depends

  constructor: (props) ->
    @[key] = val for own key, val of props

    @DEFAULT_TIMEOUT ?= 10000
    @Error ?= Error
    @Promise ?= Promise

    @$object ?=
      keys: (object) ->
        return Object.keys(object) if Object.keys?
        (key for own key of object)
      assign: (args...) ->
        return Object.assign(args...) if Object.assign?
        args.reduce (memo, props) ->
          memo[key] = val for own key, val of props
          memo
      entries: (object) ->
        return Object.entries(object) if Object.entries?
        ([key, val] for own key, val of object)

    @$promise ?=
      resolve: (value) =>
        return @Promise.resolve(value) if @Promise.resolve?
        new @Promise (resolve) -> resolve value

configure = (props) ->
  { DEFAULT_TIMEOUT, Error, Promise, $object, $promise } = depends = new Depends props

  class Exception extends Error
    constructor: (payload) ->
      super()

      @name = @constructor.name
      @payload = payload
      @message = @getMessage payload

      if typeof Error.captureStackTrace is 'function'
        Error.captureStackTrace this, @constructor

  class ComponentHasCircularDependency extends Exception
    getMessage: ({ key, stack }) ->
      str = [key].concat(stack).join ' < '
      "Component '#{key}' has circular dependency '#{str}'"

  class ComponentDependencyNotDefined extends Exception
    getMessage: ({ key, stack }) ->
      "Component '#{stack[0]}' dependency not defined '#{key}'"

  class ComponentNotDefined extends Exception
    getMessage: ({ key }) ->
      "Component '#{key}' is not defined"

  # TODO : rename?
  class DependsNotParseable extends Exception
    getMessage: ({ depends }) ->
      "Cannot parse '#{depends}'\n#{JSON.stringify(depends)}"

  class ComponentTimedOut extends Exception
    getMessage: ({ key, timeout } = {}) ->
      "Component '#{key}' timed out after #{timeout / 1000}s"

  class FactoryNotValid extends Exception
    getMessage: ({ key }) ->
      "Component `#{key}` factory not valid."

  class Container
    definitions: null
    promises: null
    timeout: null

    constructor: (props) ->
      $object.assign @, props

      @definitions ?= {}
      @promises ?= {}
      @timeout ?= DEFAULT_TIMEOUT

    define: (args...) ->
      type = (n) ->
        t = typeof args[n]
        return 'array' if Array.isArray args[n]
        return 'null' if args[n] is null
        return 'definition' if t and args[n].factory?
        return t

      types = args.map((val, i) -> type i).join(', ')

      if types is 'object'
        [definitions] = args
        @define(key, val) for own key, val of definitions
        return

      if types is 'string, definition'
        [key, definition] = args
        @definitions[key] = definition
        return

      if types is 'string, function'
        [key, factory] = args
        @definitions[key] = { factory }
        return

      if types in ['string, array, function', 'string, string, function', 'string, object, function', 'string, function, function']
        [key, depends, factory] = args
        @definitions[key] = { depends, factory }
        return

      throw Error "Invalid arguments for #define: #{JSON.stringify(args)}"

    override: (overrides = {}) ->
      $object.assign val, overrides[key] for own key, val of @definitions

    parse: (depends) ->
      return [] unless depends?
      type = if Array.isArray(depends) then 'array' else typeof depends

      switch type
        when 'function'
          @parseFunction depends
        when 'string'
          @parseString depends
        when 'array'
          @parseArray depends
        when 'object'
          @parseObject depends
        else
          throw new DependsNotParseable({ depends })

    parseString: (depends) ->
      pattern = /^(.+)\sas\s(.+)$/
      [_, key, alias] = pattern.exec(depends) ? [ null, depends, depends ]
      [{ key, alias }]

    parseArray: (depends) ->
      depends.map (str) =>
        @parseString(str)[0]

    parseObject: (depends) ->
      $object.entries(depends).map ([alias, key]) =>
        key = alias unless typeof key is 'string'
        { key, alias }

    parseFunction: (depends) ->
      @parseArray $object.keys(@definitions).reduce(depends, [])

    resolve: (depends) ->
      @resolveSchema @parse(depends)

    resolveSchema: (schema) ->
      reduceFn = (memo, { key, alias }) =>
        memo.then (values) =>
          @resolveComponent(key).then (value) =>
            $object.assign values, "#{alias ? key}": value

      schema.reduce reduceFn, $promise.resolve({})

    createComponentPromise: (key) ->
      { factory, depends } = @definitions[key]

      schema = @parse depends

      @resolveSchema(schema).then (params) =>

        new Promise (resolve, reject) =>

          resolver = (error, result) ->
            return reject(error) if error?
            return resolve(result)

          resolver.resolve = resolve
          resolver.reject = reject

          arity = factory.length
          hasParams = !!schema.length

          # sync factories / promises
          if arity is 0 and !hasParams
            return resolve factory()
          if arity is 1 and hasParams
            return resolve factory(params)

          # async factories / deferreds
          if arity is 1 and !hasParams
            return factory resolver
          if arity is 2 and hasParams
            return factory params, resolver

          throw new FactoryNotValid({ key })

    timeoutComponentPromise: (key, promise, timeout) ->
      new Promise (resolve, reject) ->

        onTimeout = ->
          reject new ComponentTimedOut({ key })
          resolve = reject = ->

        clearsTimeout = (timeoutId, fn) -> (args...) ->
          fn args...
          clearTimeout timeoutId
          resolve = reject = ->

        timeoutId = setTimeout onTimeout, timeout

        onResolved = clearsTimeout timeoutId, (result) ->
          resolve result

        onRejected = clearsTimeout timeoutId, (error) ->
          reject error

        promise.then onResolved, onRejected

    resolveComponent: (key) ->
      return @promises[key] if @promises[key]?

      @validate(key)

      timeout = @definitions[key].timeout ? @timeout ? DEFAULT_TIMEOUT
      promise = @createComponentPromise key

      @promises[key] = @timeoutComponentPromise key, promise, timeout

    validate: (key, stack = []) ->

      if key in stack
        throw new ComponentHasCircularDependency({ key, stack })

      if !@definitions[key]? and stack.length
        throw new ComponentDependencyNotDefined({ key, stack })

      if !@definitions[key]? and !stack.length
        throw new ComponentNotDefined({ key })

      { depends }= @definitions[key]

      @parse(depends).forEach (dep) =>
        @validate dep.key, [key].concat(stack)

    validateAll: ->
      @validate key for own key of @definitions

  return {
    Exception
    ComponentHasCircularDependency
    ComponentDependencyNotDefined
    ComponentNotDefined
    ComponentTimedOut
    FactoryNotValid
    Container
    configure
    depends
  }

exports.configure = configure
exports.Depends = Depends
