# OPENAPI (swagger) specification feature

debug = require('debug')('yang:openapi') if process.env.DEBUG?
Yang = require 'yang-js'
yaml = require 'js-yaml'

# TODO: this should be handled via separate yang-json-schema module
definitions = {}
yang2jstype = (schema) ->
  jschema =
    description: schema.description?.tag
    default: schema.default?.tag
  return jschema unless schema.type?
  datatype = switch schema.type.primitive
    when 'uint8','int8'
      type: 'integer'
      format: 'byte'
    when 'uint16','uint32','uint64','int16','int32','int64'
      type: 'integer'
      format: schema.type.primitive
    when 'binary'
      type: 'string'
      format: 'binary'
    when 'decimal64'
      type: 'number'
      format: 'double'
    when 'union'
      anyOf: [] # TODO
    when 'boolean'
      type: 'boolean'
      format: schema.type.tag
    when 'enumeration'
      type: 'string'
      format: schema.type.tag
      enum: schema.type.enum.map (e) -> e.tag
    else
      # TODO: handle pattern?
      type: 'string'
      format: schema.type.tag
  jschema[k] = v for k, v of datatype
  return jschema

yang2jsobj = (schema) ->
  required = []
  property = schema.nodes
    .filter (x) -> x.parent is schema
    .map (node) ->
      if node.mandatory?.valueOf() is true
        required.push node.tag
      name: node.tag
      schema: yang2jschema node
  if schema.uses?
    description: schema.description?.tag
    allOf: schema.uses
      .map (x) -> 
        definitions[x.tag] = yang2jschema x.grouping
        '$ref': "#/definitions/#{x.tag}"
      .concat {
        required: required if required.length
        property: property if property.length
      }
  else
    type: 'object'
    description: schema.description?.tag
    required: required if required.length
    property: property if property.length

yang2jschema = (schema, collection=false) ->
  return {} unless schema?
  switch schema.kind
    when 'leaf'      then yang2jstype schema
    when 'leaf-list' then type: 'array', items: yang2jstype schema
    when 'container' then yang2jsobj schema
    when 'list'
      if collection then type: 'array', items: yang2jsobj schema
      else yang2jsobj schema
    else {}

discoverOperations = (schema, item=false) ->
  debug? "discover operations for #{schema.trail}"
  deprecated = schema.status?.valueOf() is 'deprecated'
  switch 
    when schema.kind is 'rpc' then [
      method: 'post'
      summary: "Invokes #{schema.tag} in #{schema.parent.tag}."
      deprecated: deprecated
      response: [
        code: 200
        schema: yang2jschema schema.output
      ]
    ]
    when schema.kind is 'list' and not item then [
      method: 'post'
      summary: "Creates one or more new #{schema.tag} in #{schema.parent.tag}."
      deprecated: deprecated
      response: [
        code: 200
        description: "Expected response for creating #{schema.tag}(s) in collection"
        schema: yang2jschema schema, true
      ]
     ,
      method: 'get'
      description: schema.description
      summary: "List all #{schema.tag}s from #{schema.parent.tag}"
      deprecated: deprecated
      response: [
        code: 200
        description: "Expected response of #{schema.tag}s"
        schema: yang2jschema schema, true
      ]
     ,
      method: 'put'
      summary: "Replace the entire #{schema.tag} collection"
      deprecated: deprecated
      response: [
        code: 201
        description: "Expected response for replacing collection"
      ]
     ,
      method: 'patch'
      summary: "Merge items into the #{schema.tag} collection"
      deprecated: deprecated
      response: [
        code: 201
        description: "Expected response for merging into collection"
      ]
    ]
    else [
      method: 'get'
      description: schema.description
      summary: "View detail on #{schema.tag}"
      deprecated: deprecated
      response: [
        code: 200
        description: "Expected response of #{schema.tag}"
        schema: yang2jschema schema
      ]
     ,
      method: 'put'
      summary: "Update details on #{schema.tag}"
      deprecated: deprecated
      response: [
        code: 200
        description: "Expected response of #{schema.tag}"
        schema: yang2jschema schema
      ]
     ,
      method: 'patch'
      summary: "Merge details on #{schema.tag}"
      deprecated: deprecated
      response: [
        code: 200
        description: "Expected response of #{schema.tag}"
        schema: yang2jschema schema
      ]
     ,
      method: 'delete'
      summary: "Deletes a #{schema.tag} from #{schema.parent.tag}."
      deprecated: deprecated
      response: [
        code: 204
        description: "Expected response for delete"
      ]
    ]

discoverPaths = (schema) ->
  return [] unless schema.kind in [ 'list', 'container', 'rpc' ]
  name = "/#{schema.datakey}"
  debug? "discover paths for #{name}"
  paths = [
    name: name
    operation: discoverOperations schema
  ]
  subpaths = (discoverPaths sub for sub in schema.nodes)
  switch schema.kind
    when 'list'
      key = schema.key?.valueOf() ? 'id'
      paths.push
        name: "#{name}/{#{key}}"
        operations: discoverOperations(schema,true)
      subpaths.forEach (x) -> x.name = "#{name}/{#{key}}" + x.name
    when 'container'
      subpaths.forEach (x) -> x.name = name + x.name
  debug? "discovered #{paths.length} paths with #{subpaths.length} subpaths"
  paths.concat subpaths...

module.exports = require('./yang-openapi.yang').bind {

  transform: ->
    modules = @input.modules.map (name) => @schema.constructor.import(name)
    definitions = {} # usage of globals is a hack
    @output =
      info: @get('/info')
      consumes: [ "application/json" ]
      produces: [ "application/json" ]
      path: modules
        .map (m) -> discoverPaths(schema) for schema in m.nodes
        .reduce ((a,b) -> a.concat b), []
      definition: (name: k, schema: v for k, v of definitions)
    
}
