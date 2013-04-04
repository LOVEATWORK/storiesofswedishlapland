
async = require 'async'
config = require './config'
instagram = require 'instagram-node-lib'
{Model} = require './model'

instagram.set 'client_id', config.instagram_id
instagram.set 'client_secret', config.instagram_secret

mapRange = (value, inputRange, outputRange=[0, 1]) ->
  ((value - inputRange[0]) / (inputRange[1] - inputRange[0]) * (outputRange[1] - outputRange[0]) + outputRange[0])

randomLocation = ->
  return {
    latitude: mapRange Math.random(), [0, 1], [-90, 90]
    longitude: mapRange Math.random(), [0, 1], [-180, 180]
  }

resolveReach = (media, callback) ->
  ### Resolve instagram *media* likes and comments to users with geodata. ###
  # TODO: need a oauth server to access user info randomly create data for now
  rv = []
  for like in media.likes
    rv.push
      username: like.username
      followers: ~~(Math.random() * 100)
      location: randomLocation()
  for comment in media.comments
    rv.push
      username: comment.from.username
      followers: ~~(Math.random() * 100)
      location: randomLocation()
  callback null, rv


# points of interest, posts collected 5km around point
poi = [
  {lat: 65.5843, lng: 22.1467, name: 'Luleå'}
  {lat: 65.825282, lng: 21.665039, name: 'Bodn'}
]

class DataModel extends Model
  constructor: (@id, @data) ->
  serialize: -> {@id, @data}

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
        error: callback
        complete: (data) -> callback null, data
    (media, callback) ->
      resolveReach media, (error, result) ->
        # TODO: handle media without location
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
    error: (message) -> callback new Error message

class User extends DataModel

User.new = (id, callback) ->
  instagram.users.recent
    user_id: id
    error: callback
    complete: (data) ->
      callback null, new User id, dat

if require.main is module
  poi.forEach (point) ->
    Node.nodesForLocation point, (error, result) ->
      throw error if error?
      console.log "Reach nodes for #{ point.name }:"
      console.dir result
