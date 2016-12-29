const Promise = require('bluebird')
const Krate = require('krate').configure({ Promise })
const container = new Krate.Container({ timeout: 5000 })
const define = container.define.bind(container)
const resolve = container.resolve.bind(container)

define('foo', () => 'FOO') // return a value
define('bar', () => Promise.resolve('BAR')) // return a promise
define('baz', (done) => done(null, 'BAZ')) // callback style
define('qux', (deferred) => deferred.resolve('QUX')) // using deferred

define({
  'character/solo': () => ('Han Solo'),
  'character/leia': () => ('Princess Leia'),
  'character/vader': () => ('Darth Vader'),
  'character/palpatine': () => ('Emperor Palpatine')
})

define('foofoo', 'foo as val', ({ val }) => val + val)
define('foobar', ['foo', 'bar as b'], ({ foo, b }) => foo + b)
define('barbaz', { bar: true, b: 'baz' }, ({ bar, b }) => bar + b)

define('characters', {
  factory: (characters) => ( characters ),
  depends: (memo, key, i) => {
    const prefix = 'character/'
    if(key.indexOf(prefix) !== 0) return memo
    return memo.concat(`${key} as ${key.slice(prefix.length)}`)
  }
})

define({
  good: {
    depends: 'characters',
    factory: ({ characters }) => {
      const { solo, leia } = characters
      return { solo, leia }
    }
  },
  evil: {
    depends: 'characters',
    factory: ({ characters }) => {
      const { vader, palpatine } = characters
      return { vader, palpatine }
    }
  }
})

resolve([
  'foofoo',
  'foobar',
  'barbaz',
  'good',
  'evil'
]).then((everything) => {
   console.log(everything)
})

// #=>
// foofoo: "FOOFOO"
// foobar: "FOOBAR"
// barbaz: "BARBAZ"
// good: {
//   solo: "Han Solo",
//   leia: "Princess Leia"
// }
// bad: {
//   vader: "Darth Vader"
//   palpatine: "Emperor Palpatine"
// }
