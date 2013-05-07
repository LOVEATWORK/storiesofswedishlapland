async = require 'async'
https = require 'https'
parseUrl = require('url').parse
querystring = require 'querystring'
zlib = require 'zlib'

requestTimeout = 30 # in seconds
retryDelay = 250 # milliseconds

# this error happens frequently, probably when their servers are overloaded
isMediaSearchError = (error) ->
  (error.body?.meta?.error_message is 'Media search error. Please try again shortly')

fetchUrl = (url, callback) ->
  opts = parseUrl url
  opts.headers =
    'Accept': 'application/json,text/plain,*/*;q=0.9'
    'User-Agent': 'coffeegram/1.0-pre'
    'Accept-Encoding': 'gzip'

  request = https.get opts, (response) ->
    if response.headers['content-encoding'] is 'gzip'
      gzip = zlib.createGunzip()
      response.pipe(gzip)
      output = gzip
    else
      output = response

    data = []
    output.on 'error', callback
    output.on 'data', (chunk) -> data.push chunk
    output.on 'end', ->
      if response.headers['content-type'].indexOf('application/json') isnt -1
        try
          data = JSON.parse Buffer.concat data
        catch error
          error.message = "Invalid JSON response (#{ error.message })"
          error.code = response.statusCode
          return callback error
      else
        data = Buffer.concat(data).toString()

      if Math.floor(response.statusCode / 100) isnt 2
        error = new Error "HTTP: #{ response.statusCode }"
        error.code = response.statusCode
        error.body = data
        callback error
      else
        callback null, data

  request.on 'error', callback
  request.setTimeout requestTimeout * 1000, ->
    callback new Error 'Request timed out'

fetchInstagram = (url, callback) ->
  fetchUrl url, (error, result) ->
    return callback error if error?
    {data, pagination} = result
    if pagination?
      last = result
      numPages = 0 # TODO: make pagination configurable
      async.whilst (-> last.pagination?.next_url? and numPages < 3), (callback) ->
        fetchUrl last.pagination.next_url, (error, result) ->
          return callback error if error?
          data = data.concat result.data
          last = result
          numPages++
          callback()
      , (error) ->
        callback error, data
    else
      callback null, data

class Instagram
  baseUrl = 'https://api.instagram.com/v1/'

  constructor: (@accessToken, concurrency=5) ->
    @maxTries = 10 # how many times to retry a request before failing
    @queue = async.queue @worker, concurrency

  mediaInfo: (mediaId, callback) ->
    ### Get information about a media object. ###
    @send "media/#{ mediaId }", {}, callback

  mediaSearch: (lat, lng, callback) ->
    ### Search for media in a given area. ###
    now = Math.floor(Date.now() / 1000)
    opts =
      lat: lat
      lng: lng
      max_timestamp: now
      min_timestamp: now - 60 * 60 * 24 * 6
      distance: 5000 # 5km
    @send 'media/search', opts, callback

  userInfo: (userId, callback) ->
    ### Get basic information about a user. ###
    @send "users/#{ userId }", {}, callback

  userRecent: (userId, callback) ->
    ### Get the most recent media published by a user. ###
    @send "users/#{ userId }/media/recent", {}, callback

  tagRecent: (tag, callback) ->
    ### Get a list of recently tagged media. ###
    @send "tags/#{ tag }/media/recent", {}, callback

  ### Private ###

  send: (endpoint, opts, callback) ->
    if not @accessToken?
      return callback new Error 'Missing access token'
    opts.access_token = @accessToken
    url = baseUrl + endpoint + '?' + querystring.stringify(opts)
    @queue.push {url, endpoint}, callback

  worker: (task, callback) =>
    tries = 0
    result = null
    async.until (-> result?), (callback) =>
      tries++
      fetchInstagram task.url, (error, res) =>
        result = res
        if error?
          if tries > @maxTries or (error.code is 400 and !isMediaSearchError(error))
            callback error
          else
            setTimeout callback, retryDelay
        else
          callback()
    , (error) ->
      callback error, result

Instagram.getAuthUrl = (clientId, redirectUri) ->
  'https://instagram.com/oauth/authorize/?' + querystring.stringify
    client_id: clientId
    redirect_uri: redirectUri
    response_type: 'token'

module.exports = Instagram
