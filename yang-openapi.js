// Generated by CoffeeScript 1.11.1
(function() {
  var Yang, clone, debug, definitions, discoverOperations, discoverPaths, serializeJSchema, traverse, yaml, yang2jschema, yang2jsobj, yang2jstype;

  if (process.env.DEBUG != null) {
    debug = require('debug')('yang:openapi');
  }

  clone = require('clone');

  traverse = require('traverse');

  Yang = require('yang-js');

  yaml = require('js-yaml');

  definitions = {};

  yang2jstype = function(schema) {
    var datatype, js, k, ref1, ref2, v;
    js = {
      description: (ref1 = schema.description) != null ? ref1.tag : void 0,
      "default": (ref2 = schema["default"]) != null ? ref2.tag : void 0
    };
    if (schema.type == null) {
      return js;
    }
    datatype = (function() {
      switch (schema.type.primitive) {
        case 'uint8':
        case 'int8':
          return {
            type: 'integer',
            format: 'byte'
          };
        case 'uint16':
        case 'uint32':
        case 'uint64':
        case 'int16':
        case 'int32':
        case 'int64':
          return {
            type: 'integer',
            format: schema.type.primitive
          };
        case 'binary':
          return {
            type: 'string',
            format: 'binary'
          };
        case 'decimal64':
          return {
            type: 'number',
            format: 'double'
          };
        case 'union':
          return {
            anyOf: []
          };
        case 'boolean':
          return {
            type: 'boolean',
            format: schema.type.tag
          };
        case 'enumeration':
          return {
            type: 'string',
            format: schema.type.tag,
            "enum": schema.type["enum"].map(function(e) {
              return e.tag;
            })
          };
        default:
          return {
            type: 'string',
            format: schema.type.tag
          };
      }
    })();
    for (k in datatype) {
      v = datatype[k];
      js[k] = v;
    }
    return js;
  };

  yang2jsobj = function(schema) {
    var js, property, ref, ref1, ref2, refs, required;
    if (schema == null) {
      return {};
    }
    if (typeof debug === "function") {
      debug("[" + schema.trail + "] converting schema to JSON-schema");
    }
    js = {
      description: (ref1 = schema.description) != null ? ref1.tag : void 0
    };
    required = [];
    property = schema.nodes.filter(function(x) {
      return x.parent === schema;
    }).map(function(node) {
      var ref2;
      if (((ref2 = node.mandatory) != null ? ref2.valueOf() : void 0) === true) {
        required.push(node.tag);
      }
      return {
        name: node.tag,
        schema: yang2jschema(node)
      };
    });
    refs = (ref2 = schema.uses) != null ? ref2.filter(function(x) {
      return x.parent === schema;
    }) : void 0;
    if (refs != null ? refs.length : void 0) {
      refs.forEach(function(ref) {
        if (definitions[ref.tag] == null) {
          if (typeof debug === "function") {
            debug("[" + schema.trail + "] defining " + ref.tag);
          }
          definitions[ref.tag] = true;
          return definitions[ref.tag] = yang2jsobj(ref.state.grouping.origin);
        }
      });
      if (refs.length > 1 || property.length) {
        js.allOf = refs.map(function(ref) {
          return {
            '$ref': "#/definitions/" + ref.tag
          };
        });
        if (property.length) {
          js.allOf.push({
            required: required,
            property: property
          });
        }
      } else {
        ref = refs[0];
        js['$ref'] = "#/definitions/" + ref.tag;
      }
    } else {
      js.type = 'object';
      if (required.length) {
        js.required = required;
      }
      if (property.length) {
        js.property = property;
      }
    }
    return js;
  };

  yang2jschema = function(schema, item) {
    if (item == null) {
      item = false;
    }
    if (schema == null) {
      return {};
    }
    switch (schema.kind) {
      case 'leaf':
        return yang2jstype(schema);
      case 'leaf-list':
        return {
          type: 'array',
          items: yang2jstype(schema)
        };
      case 'list':
        if (!item) {
          return {
            type: 'array',
            items: yang2jsobj(schema)
          };
        } else {
          return yang2jsobj(schema);
        }
        break;
      case 'grouping':
        return {};
      default:
        return yang2jsobj(schema);
    }
  };

  discoverOperations = function(schema, item) {
    var deprecated, ref1;
    if (item == null) {
      item = false;
    }
    if (typeof debug === "function") {
      debug("[" + schema.trail + "] discovering operations");
    }
    deprecated = ((ref1 = schema.status) != null ? ref1.valueOf() : void 0) === 'deprecated';
    switch (false) {
      case schema.kind !== 'rpc':
        return [
          {
            method: 'post',
            summary: "Invokes " + schema.tag + " in " + schema.parent.tag + ".",
            deprecated: deprecated,
            response: [
              {
                code: 200,
                schema: yang2jschema(schema.output)
              }
            ]
          }
        ];
      case !(schema.kind === 'list' && !item):
        return [
          {
            method: 'post',
            summary: "Creates one or more new " + schema.tag + " in " + schema.parent.tag + ".",
            deprecated: deprecated,
            response: [
              {
                code: 200,
                description: "Expected response for creating " + schema.tag + "(s) in collection",
                schema: yang2jschema(schema)
              }
            ]
          }, {
            method: 'get',
            description: schema.description,
            summary: "List all " + schema.tag + "s from " + schema.parent.tag,
            deprecated: deprecated,
            response: [
              {
                code: 200,
                description: "Expected response of " + schema.tag + "s",
                schema: yang2jschema(schema)
              }
            ]
          }, {
            method: 'put',
            summary: "Replace the entire " + schema.tag + " collection",
            deprecated: deprecated,
            response: [
              {
                code: 201,
                description: "Expected response for replacing collection"
              }
            ]
          }, {
            method: 'patch',
            summary: "Merge items into the " + schema.tag + " collection",
            deprecated: deprecated,
            response: [
              {
                code: 201,
                description: "Expected response for merging into collection"
              }
            ]
          }
        ];
      default:
        return [
          {
            method: 'get',
            description: schema.description,
            summary: "View detail on " + schema.tag,
            deprecated: deprecated,
            response: [
              {
                code: 200,
                description: "Expected response of " + schema.tag,
                schema: yang2jschema(schema, item)
              }
            ]
          }, {
            method: 'put',
            summary: "Update details on " + schema.tag,
            deprecated: deprecated,
            response: [
              {
                code: 200,
                description: "Expected response of " + schema.tag,
                schema: yang2jschema(schema, item)
              }
            ]
          }, {
            method: 'patch',
            summary: "Merge details on " + schema.tag,
            deprecated: deprecated,
            response: [
              {
                code: 200,
                description: "Expected response of " + schema.tag,
                schema: yang2jschema(schema, item)
              }
            ]
          }, {
            method: 'delete',
            summary: "Delete " + schema.tag + " from " + schema.parent.tag + ".",
            deprecated: deprecated,
            response: [
              {
                code: 204,
                description: "Expected response for delete"
              }
            ]
          }
        ];
    }
  };

  discoverPaths = function(schema) {
    var key, name, paths, ref1, ref2, ref3, ref4, sub, subpaths;
    if ((ref1 = schema.kind) !== 'list' && ref1 !== 'container' && ref1 !== 'rpc') {
      return [];
    }
    name = "/" + schema.datakey;
    if (typeof debug === "function") {
      debug("[" + schema.trail + "] discovering paths");
    }
    paths = [
      {
        name: name,
        operation: discoverOperations(schema)
      }
    ];
    subpaths = (ref2 = []).concat.apply(ref2, (function() {
      var i, len, ref2, results;
      ref2 = schema.nodes;
      results = [];
      for (i = 0, len = ref2.length; i < len; i++) {
        sub = ref2[i];
        results.push(discoverPaths(sub));
      }
      return results;
    })());
    switch (schema.kind) {
      case 'list':
        key = (ref3 = (ref4 = schema.key) != null ? ref4.valueOf() : void 0) != null ? ref3 : 'id';
        paths.push({
          name: name + "/{" + key + "}",
          operations: discoverOperations(schema, true)
        });
        subpaths.forEach(function(x) {
          return x.name = (name + "/{" + key + "}") + x.name;
        });
        break;
      case 'container':
        subpaths.forEach(function(x) {
          return x.name = name + x.name;
        });
    }
    if (typeof debug === "function") {
      debug("[" + schema.trail + "] discovered " + paths.length + " paths with " + subpaths.length + " subpaths");
    }
    return paths.concat.apply(paths, subpaths);
  };

  serializeJSchema = function(jschema) {
    var k, o, ref1, ref2, ref3, ref4, v;
    if (jschema == null) {
      return;
    }
    o = {};
    for (k in jschema) {
      v = jschema[k];
      if (k !== 'property') {
        o[k] = v;
      }
    }
    o.properties = (ref1 = jschema.property) != null ? ref1.reduce((function(a, _prop) {
      a[_prop.name] = serializeJSchema(_prop.schema);
      return a;
    }), {}) : void 0;
    o.items = serializeJSchema(o.items);
    o.allOf = (ref2 = o.allOf) != null ? ref2.map(function(x) {
      return serializeJSchema(x);
    }) : void 0;
    o.anyOf = (ref3 = o.anyOf) != null ? ref3.map(function(x) {
      return serializeJSchema(x);
    }) : void 0;
    o.oneOf = (ref4 = o.oneOf) != null ? ref4.map(function(x) {
      return serializeJSchema(x);
    }) : void 0;
    return o;
  };

  module.exports = require('./yang-openapi.yang').bind({
    transform: function() {
      var k, modules, v;
      modules = this.input.modules.map((function(_this) {
        return function(name) {
          return _this.schema.constructor["import"](name);
        };
      })(this));
      if (typeof debug === "function") {
        debug("transforming " + this.input.modules + " into yang-openapi");
      }
      definitions = {};
      return this.output = {
        swagger: '2.0',
        info: this.get('/info'),
        consumes: ["application/json"],
        produces: ["application/json"],
        path: modules.map(function(m) {
          var i, len, ref1, results, schema;
          ref1 = m.nodes;
          results = [];
          for (i = 0, len = ref1.length; i < len; i++) {
            schema = ref1[i];
            results.push(discoverPaths(schema));
          }
          return results;
        }).reduce((function(a, b) {
          return a.concat.apply(a, b);
        }), []),
        definition: (function() {
          var results;
          results = [];
          for (k in definitions) {
            v = definitions[k];
            results.push({
              name: k,
              schema: v
            });
          }
          return results;
        })()
      };
    },
    serialize: function() {
      var spec;
      if (typeof debug === "function") {
        debug("serializing yang-openapi spec");
      }
      spec = clone(this.input.spec);
      spec.paths = spec.path.reduce((function(a, _path) {
        var i, k, len, op, operation, path, ref1, v;
        path = a[_path.name] = {
          '$ref': _path['$ref']
        };
        ref1 = _path.operation;
        for (i = 0, len = ref1.length; i < len; i++) {
          op = ref1[i];
          operation = path[op.method] = {};
          for (k in op) {
            v = op[k];
            if (k !== 'response') {
              operation[k] = v;
            }
          }
          operation.responses = op.response.reduce((function(x, _res) {
            x[_res.code] = {
              description: _res.description,
              schema: serializeJSchema(_res.schema)
            };
            return x;
          }), {});
        }
        return a;
      }), {});
      spec.definitions = spec.definition.reduce((function(a, _def) {
        a[_def.name] = serializeJSchema(_def.schema);
        return a;
      }), {});
      delete spec.path;
      delete spec.definition;
      spec = traverse(spec).map(function(x) {
        if (x == null) {
          return this.remove();
        }
      });
      return this.output = (function() {
        switch (this.input.format) {
          case 'json':
            return JSON.stringify(spec, null, 2);
          case 'yaml':
            return yaml.dump(spec);
        }
      }).call(this);
    }
  });

}).call(this);