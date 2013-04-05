
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

  safeGet @db(), id, (error, result) =>
    return callback error if error?
    if not result? or ignoreCache
      this.new id, (error, result) ->
        return callback error, result if error? or not result?
        result.save (error) -> callback error, result
    else
      this.deserialize id, result, callback

Model.deserialize = (id, data, callback) ->
  throw new Error 'Not implemented'

Model.new = (id, callback) ->
  throw new Error 'Not implemented'

module.exports = {Model}
