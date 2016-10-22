# OPENAPI (swagger) specification feature

debug = require('debug')('yang-swagger') if process.env.DEBUG?
traverse = require 'traverse'
Yang = require 'yang-js'
yaml = require 'js-yaml'

# TODO: this should be handled via separate yang-json-schema module
definitions = {}
yang2jstype = (schema) ->
  js =
    description: schema.description?.tag
    default: schema.default?.tag
  return js unless schema.type?
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
    when 'union' # TODO
      type: 'string'
      format: schema.type.tag
      #anyOf: []
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
  js[k] = v for k, v of datatype
  return js

yang2jsobj = (schema) ->
  return {} unless schema?
  #debug? "[#{schema.trail}] converting schema to JSON-schema"
  js =
   description: schema.description?.tag
  required = []
  property = schema.nodes
    .filter (x) -> x.kind isnt 'action' and x.parent is schema
    .map (node) ->
      if node.mandatory?.valueOf() is true
        required.push node.tag
      name: node.tag
      schema: yang2jschema node.origin ? node

  choices = schema.choice?.filter (x) -> x.parent is schema
    .map (choice) -> anyOf: choice.case?.map (node) -> yang2jsobj node.origin ? node
      
  refs = schema.uses?.filter (x) -> x.parent is schema
  switch
    when refs?.length
      refs.forEach (ref) ->
        unless definitions[ref.tag]?
          debug? "[yang2jsobj] defining #{ref.tag} using #{schema.trail}"
          definitions[ref.tag] = true
          definitions[ref.tag] = yang2jsobj ref.state.grouping.origin

      if refs.length > 1 or property.length
        js.allOf = refs.map (ref) -> '$ref': "#/definitions/#{ref.tag}"
        if property.length
          js.allOf.push
            required: if required.length then required else undefined
            property: property
        if choices?.length
          js.allOf.push choices...
      else
        ref = refs[0]
        js['$ref'] = "#/definitions/#{ref.tag}"
    when choices?.length
      if choices.length > 1 or property.length
        js.allOf = [].concat choices
        if property.length
          js.allOf.push
            required: if required.length then required else undefined
            property: property
      else
        js.anyOf = choices[0].anyOf
    else
      js.type = 'object'
      js.property = property if property.length
      js.required = required if required.length
  return js

yang2jschema = (schema, item=false) ->
  return {} unless schema?
  switch schema.kind
    when 'leaf'      then yang2jstype schema
    when 'leaf-list' then type: 'array', items: yang2jstype schema
    when 'list'
      unless item then type: 'array', items: yang2jsobj schema
      else yang2jsobj schema
    when 'grouping' then {}
    else yang2jsobj schema

discoverOperations = (schema, item=false) ->
  debug? "[discoverOperations] inspecting #{schema.trail}"
  deprecated = schema.status?.valueOf() is 'deprecated'
  switch 
    when schema.kind in [ 'rpc', 'action' ] then [
      method: 'post'
      description: schema.description?.tag
      summary: "Invokes #{schema.tag} in #{schema.parent.tag}"
      deprecated: deprecated
      parameter: [
        name: "#{schema.tag}:input"
        in: 'body'
        description: schema.input?.description?.tag
        schema: yang2jschema schema.input
      ]
      response: [
        code: 200
        description: "Expected response of #{schema.tag}"
        schema: yang2jschema schema.output
      ]
    ]
    when schema.kind is 'list' and not item then [
      method: 'post'
      description: schema.description?.tag
      summary: "Creates one or more new #{schema.tag} in #{schema.parent.tag}"
      deprecated: deprecated
      parameter: [
        name: "#{schema.tag}"
        in: 'body'
        description: schema.description?.tag
        schema: yang2jschema schema
      ]
      response: [
        code: 200
        description: "Expected response for creating #{schema.tag}(s) in collection"
        schema: yang2jschema schema
      ]
     ,
      method: 'get'
      summary: "List all #{schema.tag}s from #{schema.parent.tag}"
      deprecated: deprecated
      response: [
        code: 200
        description: "Expected response of #{schema.tag}s"
        schema: yang2jschema schema
      ]
     ,
      method: 'put'
      summary: "Replace the entire #{schema.tag} collection"
      deprecated: deprecated
      parameter: [
        name: "#{schema.tag}"
        in: 'body'
        description: schema.description?.tag
        schema: yang2jschema schema
      ]
      response: [
        code: 201
        description: "Expected response for replacing collection"
      ]
     ,
      method: 'patch'
      summary: "Merge items into the #{schema.tag} collection"
      deprecated: deprecated
      parameter: [
        name: "#{schema.tag}"
        in: 'body'
        description: schema.description?.tag
        schema: yang2jschema schema
      ]
      response: [
        code: 201
        description: "Expected response for merging into collection"
      ]
    ]
    else [
      method: 'get'
      description: schema.description?.tag
      summary: "View detail on #{schema.tag}"
      deprecated: deprecated
      response: [
        code: 200
        description: "Expected response of #{schema.tag}"
        schema: yang2jschema schema, item
      ]
     ,
      method: 'put'
      summary: "Update details on #{schema.tag}"
      deprecated: deprecated
      parameter: [
        name: "#{schema.tag}"
        in: 'body'
        description: schema.description?.tag
        schema: yang2jschema schema, item
      ]
      response: [
        code: 200
        description: "Expected response of #{schema.tag}"
        schema: yang2jschema schema, item
      ]
     ,
      method: 'patch'
      summary: "Merge details on #{schema.tag}"
      deprecated: deprecated
      parameter: [
        name: "#{schema.tag}"
        in: 'body'
        description: schema.description?.tag
        schema: yang2jschema schema, item
      ]
      response: [
        code: 200
        description: "Expected response of #{schema.tag}"
        schema: yang2jschema schema, item
      ]
     ,
      method: 'delete'
      summary: "Delete #{schema.tag} from #{schema.parent.tag}"
      deprecated: deprecated
      response: [
        code: 204
        description: "Expected response for delete"
      ]
    ]

discoverPathParameter = (schema) ->
  debug? "[discoverPathParameter] inspecting #{schema.trail}"
  switch
    when not schema.key?
      name: 'index'
      in: 'path'
      required: true
      type: 'integer'
      format: 'int64'
      description: "An index key identifying #{schema.tag} item (may change over time)"
    when schema.key.tag.length > 1
      name: "#{schema.key.valueOf()}"
      in: 'path'
      required: true
      type: 'string'
      format: 'composite'
      description: "A composite key uniquely identifying #{schema.tag} item"
    else
      param =
        name: "#{schema.key.valueOf()}"
        in: 'path'
        required: true
        description: "A key uniquely identifying #{schema.tag} item"
      param[k] = v for k, v of yang2jstype schema.locate(param.name) when v?
      return param

discoverPaths = (schema) ->
  return [] unless schema.kind in [ 'list', 'container', 'rpc', 'action' ]
  return [] if schema['if-feature']? # ignore if-feature entries...
  
  name = "/#{schema.datakey}"
  debug? "[discoverPaths] inspecting #{schema.trail}"
  paths = [
    name: name
    operation: discoverOperations schema
  ]
  subpaths = [].concat (discoverPaths sub for sub in schema.nodes)...
  switch schema.kind
    when 'list'
      param = discoverPathParameter(schema)
      # test if any subpaths have same param.name
      for sub in subpaths
        if (sub.parameter?.some (x) -> x.name is param.name)
          param.name = "#{schema.tag}-#{param.name}"
          break
      subpaths.forEach (x) ->
        x.parameter?.push param
        x.parameter ?= [ param ]
        x.name = "#{name}/{#{param.name}}" + x.name
        debug? "[discoverPaths] subpath #{x.name} has parameters: #{x.parameter.map (p) -> p.name}"
      paths.push
        name: "#{name}/{#{param.name}}"
        parameter: [ param ]
        operation: discoverOperations(schema,true)
    when 'container'
      subpaths.forEach (x) -> x.name = name + x.name
  debug? "[discoverPaths] discovered #{paths.length} paths with #{subpaths.length} subpaths inside #{schema.trail}"
  paths.concat subpaths...

serializeJSchema = (jschema) ->
  return unless jschema?
  o = {}
  o[k] = v for k, v of jschema when k isnt 'property'
  o.properties = jschema.property?.reduce ((a, _prop) ->
    a[_prop.name] = serializeJSchema _prop.schema
    return a
  ), {}
  o.items = serializeJSchema o.items
  o.allOf = o.allOf?.map (x) -> serializeJSchema x

  # Swagger 2.0 does NOT support anyOf or oneOf
  #o.anyOf = o.anyOf?.map (x) -> serializeJSchema x
  #o.oneOf = o.oneOf?.map (x) -> serializeJSchema x
  if o.anyOf?
    o.type ?= 'object'
    o.properties ?= {}
    o.anyOf.forEach (x) ->
      x.property?.forEach (prop) ->
        o.properties[prop.name] = serializeJSchema prop.schema
    delete o.anyOf
  return o

module.exports = require('./yang-openapi.yang').bind {

  transform: ->
    debug? "[transform] using '#{@input['@choice']}' as source"
    switch @input['@choice']
      when 'swagger-file' then @throw "swagger-file transform feature not yet supported!"
    debug? "[transform] importing '#{@input.modules}'"
    modules = @input.modules
      .map (name) => @schema.constructor.import(name)
      .filter (x) -> x?
    unless modules.length
      @throw "unable to transform without any modules"
    found = modules.map (x) -> x.datakey
    debug? "[transform] transforming #{found}"
    definitions = {} # XXX - usage of globals is a hack (will have concurrency issues)
    @output =
      spec:
        swagger: '2.0'
        info: @get('/info')
        consumes: [ "application/json" ]
        produces: [ "application/json" ]
        path: modules
          .map (m) -> discoverPaths(schema) for schema in m.nodes
          .reduce ((a,b) -> a.concat b...), []
        definition: (name: k, schema: v for k, v of definitions)

  '{specification}/serialize': ->
    debug? "[#{@path}] serializing specification"
    spec = @parent.toJSON(false)
    spec.paths = spec.path.reduce ((a,_path) ->
      path = a[_path.name] = '$ref': _path['$ref']
      for op in _path.operation ? []
        operation = path[op.method] = {}
        operation[k] = v for k, v of op when k not in [ 'method', 'parameter', 'response' ]
        operation.parameters = traverse(op.parameter).map (x) ->
          @update serializeJSchema(x), true if @key is 'schema'
        operation.responses = op.response.reduce ((x,_res) ->
          x[_res.code] =
            description: _res.description
            schema: serializeJSchema _res.schema
          return x
        ), {}
      path.parameters = _path.parameter
      return a
    ), {}
    spec.definitions = spec.definition?.reduce ((a,_def) ->
      a[_def.name] = serializeJSchema _def.schema
      return a
    ), {}
    delete spec.path
    delete spec.definition
    delete spec.serialize
    spec = traverse(spec).map (x) -> @remove() unless x?
    @output =
      data: switch @input.format
        when 'json' then JSON.stringify spec, null, 2
        when 'yaml' then yaml.dump spec, lineWidth: -1
}
