
levelup = require 'levelup'
path = require 'path'

throwop = (error) -> throw error if error?

safeGet = (db, key, callback) ->
  db.get key, (error, result) ->
    if error? and error.name isnt 'NotFoundError'
      callback error
    else
      callback null, result or null

class Model

  constructor: (@id) ->

  serialize: ->
    throw new Error 'Not implemented'

  save: (callback) ->
    db = @constructor.db()
    db.put @id, @serialize(), callback

Model.dblocation = path.join __dirname, '../data'

Model.db = ->
  if not @_db?
    dbpath = path.join this.dblocation, this.name.toLowerCase()
    @_db = levelup dbpath,
      keyEncoding: 'utf8'
      valueEncoding: 'json'
    process.on 'exit', => @_db.close()
  return @_db

Model.load = (id, ignoreCache, callback) ->
  if arguments.length isnt 3
    callback = arguments[1] or throwop
    ignoreCache = false

  createNew = =>
    this.new id, (error, result) ->
      return callback error, result if error? or not result?
      result.save (error) -> callback error, result

  if ignoreCache
    createNew()
  else
    safeGet @db(), id, (error, result) =>
      return callback error if error?
      if not result?
        createNew()
      else
        this.deserialize id, result, callback

Model.deserialize = (id, data, callback) ->
  throw new Error 'Not implemented'

### Implement to create a new instance if Model.load does not find a existing id in db. ###
Model.new = null # (id, callback) ->

Model.all = (callback) ->
  results = []
  stream = @db().createReadStream()
  stream.on 'data', (data) =>
    this.deserialize data.key, data.value, (error, result) ->
      if error?
        stream.close()
        callback error
        callback = null
        return
      results.push result
  stream.on 'error', (error) ->
    callback? error
  stream.on 'end', ->
    callback? null, results

module.exports = {Model}
