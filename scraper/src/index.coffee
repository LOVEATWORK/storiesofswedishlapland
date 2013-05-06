async = require 'async'
express = require 'express'
coffee = require 'coffee-script'
querystring = require 'querystring'
util = require 'util'

Instagram = require './instagram'
{Model} = require './model'

try
  config = require '../config'
catch error
  if error.code is 'MODULE_NOT_FOUND'
    process.stderr.write "Config missing! Look in config-defaults.coffee for instructions.\n"
    process.exit()
  else
    throw error

MAX_REQS = 8 # max concurrent requests

authUrl = Instagram.getAuthUrl config.instagram.id, config.instagram.redirect
instagram = new Instagram

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
  log "resolving reach for #{ media.id }"

  # users this media "reaches out" to (comments + likes)
  userIds = media.likes.data.map (like) -> like.id
  userIds = userIds.concat media.comments.data.map (comment) -> comment.from.id

  async.waterfall [
    (callback) ->
      async.mapSeries eliminateDuplicates(userIds), User.load.bind(User), callback
    (users, callback) ->
      users = users.filter (user) -> user.isValid()
      reach = users.map (user) -> user.repr()
      callback null, reach
  ], callback

class DataModel extends Model
  constructor: (@id, @data) ->
  serialize: -> @data

DataModel.deserialize = (id, data, callback) ->
  callback null, new this id, data

class Node extends DataModel
  ### A node is a instagram post and its reach ###

Node.new = (id, callback) ->
  ### Fetch instagram post *id* and resolve likes to users/positions ###
  async.waterfall [
    (callback) ->
      # fetch media
      log "fetching media #{ id }"
      instagram.mediaInfo id, callback
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
  instagram.mediaSearch location.lat, location.lng, (error, result) ->
    return callback error if error?
    log "found #{ result.length } photos at #{ location.lat },#{ location.lng }"
    async.mapLimit result, MAX_REQS, (media, callback) ->
      Node.load media.id, callback
    , callback

class User extends DataModel

  isValid: ->
    not @isPrivate() and @location()?

  isPrivate: ->
    @data is false

  location: ->
    for media in @data.recent
      return media.location if media.location?.latitude?
    return null

  repr: ->
    {location: @location(), username: @data.username, counts: @data.counts}

User.new = (id, callback) ->
  log "fetching user #{ id }"

  final = callback
  async.waterfall [
    (callback) ->
      instagram.userInfo id, (error, userdata) ->
        if error?.body?.meta?.error_type is 'APINotAllowedError'
          log "user #{ id } is private"
          final null, new User id, false
        else
          callback error, userdata
    (userdata, callback) ->
      instagram.userRecent id, (error, recent) ->
        return callback error if error?
        userdata.recent = recent
        callback null, new User id, userdata
      , callback
  ], callback

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
    instagram.accessToken = request.query.access_token
    log "token: #{ request.query.access_token }"
    buildGraph()

  response.writeHead 200, {'Content-Type': 'text/html; charset=utf-8'}
  response.end "<script>#{ coffee.compile tokengrab }</script>"

app.listen config.port
log "waiting for access token, visit #{ config.instagram.redirect }"

class Poi extends DataModel

  cleanNodes: ->
    ### Remove any duplicate nodes ###
    key = (node) -> node.id
    map = {}
    for node in @data.nodes
      map[key(node)] = node
    @data.nodes = []
    for _, node of map
      @data.nodes.push node
    return

  serialize: ->
    @cleanNodes()
    return super()

Poi.new = (id, callback) ->
  callback null, new Poi(id, {nodes: []})

updatePoi = (point, callback) ->
  log "Updating #{ point.name }... "
  async.waterfall [
    (callback) -> Poi.load point.name, callback
    (poi, callback) ->
      poi.data.name = point.name
      poi.data.location =
        latitude: point.lat
        longitude: point.lng
      Node.nodesForLocation point, (error, nodes) ->
        if not error?
          totalReach = nodes.reduce ((p, n) -> p + n.data.reach.length), 0
          log "#{ point.name }: #{ nodes.length } nodes - total reach #{ totalReach }"
          poi.data.nodes = poi.data.nodes.concat nodes
          poi.save callback
        else
          callback error
  ], callback

buildGraph = ->
  async.waterfall [
    (callback) -> async.forEachSeries config.poi, updatePoi, callback
    (callback) -> Poi.all callback
  ], (error, results) ->
    if error?
      log "ERROR: #{ error.message }\n" + util.inspect(error)
      throw error
    process.stdout.write JSON.stringify results.map((poi) -> poi.data)
    process.exit()
