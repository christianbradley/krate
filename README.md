
# ![krate.js logo](http://i.imgur.com/wjDDX95.png)

Flexible async dependency injection container for node.js and the browser.

* [installation](#installation)
* [quick start](#quick-start)
* [api](#api)

## installation

Install using [npm](http://npmjs.org)

```
npm install krate
```

## quick start

#### configure krate.js

All krate.js dependencies are injectable via the core `configure` function.
This allows you to use your own Promise library, for example.

```js
const Krate = require('krate').configure({
  DEFAULT_TIMEOUT: 10000,
  Promise: require('bluebird')
})
```


#### create a container

Your container will be used to define and resolve your app's components.

```js
const container = new Krate.Container()
```

#### define some components

Each component is defined using a `factory` that can be synchronous or asynchronous.
Synchronous factories can return a value or a promise, while async factories will be passed
a hybrid node.js-style callback/deferred resolver.

```js
container.define({
  foo: { factory: () => 'foo' },
  bar: { factory: () => Promise.resolve('bar') },
  baz: { factory: (done) => done(null, 'baz') },
  qux: { factory: (deferred) => deferred.resolve('qux') }
})
```

#### define components with dependencies

In addition to a factory, each component may define their `depends`. These will be resolved to an object and injected as the first parameter of the factory. Basic depends can be defined as strings (with "as" aliases), arrays of strings, or objects with keys representing aliases, and values representing dependency names.

```js
container.define('combos/foofoo', {
  depends: 'foo as val',
  factory: ({ val }) => val + val
})

container.define('combos/foobar', {
  depends: ['foo', 'bar as b'],
  factory: ({ foo, bar }, deferred) => deferred.resolve(foo + bar)
})

container.define('combos/barbaz', {
  depends: { b: 'bar', baz: true },
  factory: ({ b, baz }, done) => done(null, b + baz)
})
```

#### define complex dependencies with a reducer

For more complex scenarios, you can use a function to reduce the array of all defined component keys into an array of strings to be resolved as your component's `depends`.

For example, we can use a reducer to build an index of all components starting with "combos/".

```js
container.define('combos', {
  factory: (values) => values,
  depends: (depends, key, i) => {
    if(key.indexOf("combos/") !== 0) return depends
    return depends.concat(`${key} as ${key.slice(7)}`)
  }
})
```

#### resolve components

You can resolve your components using the same format you used for defining
your component's `depends`. The `resolve` method returns a promised object
with each of your resolved components, keyed by their name or their provided alias.

```js
container.resolve(['combos as c', 'foo']).then(({ c, foo }) => {
  console.log(c) // => { foobar: "foobar", barbaz: "barbaz" }
  console.log(f) // => "foo"
})
```

## api

* `configure()`
* `new Container()`
* `container.define()`
* `container.resolve()`
* `container.override()`
