# ![krate.js logo](http://i.imgur.com/krjQPnU.png)

![npm version](https://img.shields.io/npm/v/krate.svg)
![npm license](https://img.shields.io/npm/l/krate.svg)
![dependencies](https://david-dm.org/christianbradley/krate.png)


Flexible async [IOC][ioc] for javascript utilizing the [dependency injection][di] container pattern.

* [installation](#installation)
* [overview](#overview)
  * [container](#container)
  * [components](#components)
  * [factories](#factories)
  * [dependencies](#dependencies)
  * [overrides](#overrides)
* [api](#api)

## installation

Install using [npm](http://npmjs.org)

```
npm install krate
```

## overview

Using krate enables you to split your app up into multiple async or synchronous components, then define and resolve them using a dependency injection container.

Any component definition can be overridden before it is resolved, allowing you to replace dependencies, or redefine which dependencies to use for different platforms and environments.

Krate's container makes development of any sized project cleaner, faster, and easier to reason about. We think it's pretty sweet.

### container

A krate container allows you to define, resolve, and override components. You should generally only use one container per app.

Components are defined using a string `key` and a definition consisting of a `factory` and `depends` specification (dependencies). A component's key must not contain spaces, but may use other special characters.

As a general rule, you should never reference the container from any component, or define a component that resolves to the container itself.

```js
container.define({
  "test/foo": { factory: function() { return "foo" } },
  "test/bar": { factory: function() { return "bar" } },
  "test/baz": { factory: function() { return "baz" } },
  foobar: {
    depends: ['test/foo as foo', 'test/bar as bar'],
    factory: function({ foo, bar }) { return foo + bar }
  }
})

container.override('foobar', {
  depends: ['test/foo as foo', 'test/baz as bar']
})

container.resolve('foobar as f').then(function({ f }) {
  console.log(f) // #=> "foofoo"
})
```

### components

Components are identified by a string `key`, and defined by their `factory` method and optional `depends` (dependencies). A container is responsible for resolving component depends and injecting them into the factory method.

You can define components in individual files, exporting a `factory` and `depends`. This enables quick and easy modularization of your app's async components.

```js
container.define({
  DbLib: { factory: function() { return require('my-db-lib') } },
  env: { factory: function() { return process.env } },
  db: require('./components/db')
})

container.resolve(['db']).then(function({ db }) {
  // connected to db... do stuff with it
})

// db.js
exports.depends = ['DbLib', 'env']
exports.factory = function({ DbLib, env }, done) {
  DbLib.connect(env.DB_CONNSTR, done)
}
```

### factories

A component factory is a function used to resolve the value for a given component, whether it be synchronous or asynchronous. If dependencies have been defined, they will be reduced to an object and injected as the first parameter to your factory.

A factory can return any value or promise, or you may specify an additional parameter and your factory will receive a callback that doubles as a deferred object.

```js
const example_factories = {
  value: function() { return "foo" },
  promise: function() { return Promise.resolve("bar") },
  callback: function(done) { done(null, "baz") },
  deferred: function(deferred) { deferred.resolve("qux") },
  has_depends: function({ value }, done) { done(null, value) }
}
```

### dependencies

Component dependencies can be defined as a string, array of strings, or object. Each must reference an existing component key, but may pass an optional alias to use as the parameter name when injecting into the factory.

Undefined or circular dependencies (foo < bar < foo) will result in a rejected promise when attempting to resolve the component.

```js
const example_depends = {
  string: 'foo',
  string_with_alias: 'foo as f',
  strings: ['foo', 'bar as b'],
  object: {
    foo: true,
    b: 'bar'
  }
}
```

### overrides

## example app

Here's a quick, contrived example JSON api that uses a krate container. The database connection and express app components are placed in separate files, then defined on the container via a `require` statement.

The container is then used to resolve the `app` component, inject the async `db` when it is ready. After the `app` component is resolved, we can start listening.

```js
// app.js
const Promise = require('bluebird')
const Krate = require('krate').configure({ Promise })
const container = new Krate.Container()
const value = (val) => {
  return {
    depends: null,
    factory: () => val
  }
}

container.define({
  DbLib: value(require('my-db-lib')),
  Express: value(require('express')),
  env: value(process.env),
  db: require('./components/db'),
  app: require('./components/app')
})

container.resolve('app').then((app) => {
  app.listen()
})

// components/db.js
exports.depends = ['DbLib', 'env']
exports.factory = function({ DbLib, env }, done) {
  DbLib.connect(env.DB_CONNECT_STR, done)
}

// components/app.js
exports.depends = ['Express', 'db']
exports.factory = function({ Express, db }, done) {
  const app = Express()

  app.get('/posts/:id', (request, response, next) => {
    db.read("posts", request.params.id, (error, post) => {
      if(error != null) return next(error)
      response.json(post)
    })
  })

  return app
}
```

[ioc]: http://wikipedia.org/wiki/inversion_of_control
[di]: http://wikipedia.org/wiki/dependency_injection
