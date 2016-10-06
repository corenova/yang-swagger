# yang-swagger

YANG model-driven swagger/openapi transform

  [![NPM Version][npm-image]][npm-url]
  [![NPM Downloads][downloads-image]][downloads-url]

## Installation

```bash
$ npm install yang-swagger
```

## Quick Start

```bash
$ bin/yang2swagger -I yang-openapi -f yaml
```

The above example will import the `yang-openapi` YANG module and
transform into swagger specification YAML file.

You can also take a look at the generated documentation at
[Apiary](http://docs.yangswagger.apiary.io).

## License
  [Apache 2.0](LICENSE)

This software is brought to you by
[Corenova Technologies](http://www.corenova.com). We'd love to hear
your feedback.  Please feel free to reach me at <peter@corenova.com>
anytime with questions, suggestions, etc.

[npm-image]: https://img.shields.io/npm/v/yang-swagger.svg
[npm-url]: https://npmjs.org/package/yang-swagger
[downloads-image]: https://img.shields.io/npm/dt/yang-swagger.svg
[downloads-url]: https://npmjs.org/package/yang-swagger
