async = require 'async'
express = require 'express'
coffee = require 'coffee-script'
querystring = require 'querystring'
instagram = require 'instagram-node-lib'

try
  config = require '../config'
catch error
  if error.code is 'MODULE_NOT_FOUND'
    process.stderr.write "Config missing! Look in config-defaults.coffee for instructions.\n"
    process.exit()
  else
    throw error

{Model} = require './model'

MAX_REQS = 5 # max concurrent requests

instagram.set 'client_id', config.instagram.id
instagram.set 'client_secret', config.instagram.secret

authUrl = "https://instagram.com/oauth/authorize/?" + querystring.stringify
  client_id: config.instagram.id
  redirect_uri: config.instagram.redirect
  response_type: 'token'

underpErrorHandler = (callback) ->
  called = false
  return (args...) ->
    return if called
    called = true
    if args[1] is 'Oops, an error occurred.\n'
      callback new Error "500: Instagram internal server error."
    else if args[0] instanceof Error
      callback args[0]
    else
      callback new Error "#{ args[0] }: #{ args[1] }"

log = (msg, newline=true) ->
  msg += '\n' if newline
  process.stderr.write msg

eliminateDuplicates = (array) ->
  array.filter (elem, pos) -> array.indexOf(elem) is pos

mapRange = (value, inputRange, outputRange=[0, 1]) ->
  ((value - inputRange[0]) / (inputRange[1] - inputRange[0]) * (outputRange[1] - outputRange[0]) + outputRange[0])

randomLocation = ->
  return {
    latitude: mapRange Math.random(), [0, 1], [-90, 90]
    longitude: mapRange Math.random(), [0, 1], [-180, 180]
  }

resolveReach = (media, callback) ->
  ### Resolve instagram *media* likes and comments to users with geodata. ###

  # users this media "reaches out" to (comments + likes)
  userIds = media.likes.data.map (like) -> like.id
  userIds = userIds.concat media.comments.data.map (comment) -> comment.from.id

  async.waterfall [
    (callback) ->
      async.mapLimit eliminateDuplicates(userIds), MAX_REQS, User.load.bind(User), callback
    (users, callback) ->
      users = users.filter (user) -> not user.isPrivate() and user.location()?
      reach = users.map (user) -> {location: user.location()}
      # TODO: username & followers
      callback null, reach
  ], callback

class DataModel extends Model
  constructor: (@id, @data) ->
  serialize: -> @data

DataModel.deserialize = (id, data, callback) ->
  callback null, new User id, data

class Node extends DataModel
  ### A node is a instagram post and its reach ###

Node.new = (id, callback) ->
  ### Fetch instagram post *id* and resolve likes to users/positions ###
  async.waterfall [
    (callback) ->
      # fetch media
      instagram.media.info
        media_id: id
        error: underpErrorHandler(callback)
        complete: (data) -> callback null, data
    (media, callback) ->
      resolveReach media, (error, result) ->
        callback error,
          date: media.created_time
          location: media.location
          images: media.images
          reach: result
    (result, callback) ->
      callback null, new Node(id, result)
  ], callback

Node.nodesForLocation = (location, callback) ->
  instagram.media.search
    lat: location.lat
    lng: location.lng
    distance: 5000
    complete: (data) ->
      async.map data, (node, callback) ->
        Node.load node.id, callback
      , callback
    error: underpErrorHandler(callback)

class User extends DataModel

  isPrivate: ->
    @data is false

  location: ->
    for media in @data
      return media.location if media.location?
    return null

User.new = (id, callback) ->
  instagram.users.recent
    user_id: id
    error: (message, error) ->
      # NOTE: error responses here are all jumbled up. just assume 400 on any error
      callback null, new User id, false # private user
    complete: (data) ->
      callback null, new User id, data

tokengrab = """
  if window.location.hash[0..12] is '#access_token'
    token = window.location.hash.split('=')[1]
    window.location.href = '?access_token=' + token
  else if window.location.search[0..12] is '?access_token'
    document.write 'done, you can close this window'
  else
    window.location.href = '#{ authUrl }'
"""

app = express()
app.get '/', (request, response) ->
  if request.query.access_token?
    instagram.set 'access_token', request.query.access_token
    log "token: #{ request.query.access_token }"
    buildGraph()
    # Node.load '5382_72', (error, result) ->
    #   throw error if error
    #   console.log 'RESULT:', result

  response.writeHead 200, {'Content-Type': 'text/html; charset=utf-8'}
  response.end "<script>#{ coffee.compile tokengrab }</script>"

app.listen config.port
log "waiting for access token, visit #{ config.instagram.redirect }"

buildGraph = ->
  results = []
  async.eachSeries config.poi, (point, callback) ->
    log "Fetching #{ point.name }... ", false
    Node.nodesForLocation point, (error, result) ->
      if not error?
        totalReach = result.reduce ((p, n) -> p + n.data.reach.length), 0
        log " #{ result.length } posts. total reach #{ totalReach }"
        results = results.concat result
      callback error
  , (error) ->
    if error?
      throw error
    log "Done! Found #{ results.length } nodes"
    process.stdout.write JSON.stringify results
    process.exit()
