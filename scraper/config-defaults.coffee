### config.coffee template:

config = require './config-defaults'

config.instagram.id = 'myid'
config.instagram.secret = 'morganfreemanmorganfreemanmorganfreeman'

module.exports = config

###

config = {}

config.port = 3005

# points of interest, posts collected 5km around geolocation
config.poi = [
  {lat: 65.5843, lng: 22.1467, name: 'Luleå'}
  {lat: 65.825282, lng: 21.665039, name: 'Boden'}
]

config.instagram =
  id: ''
  secret: ''
  # redirect url must match instagram app settings
  redirect: 'http://localhost:' + config.port

module.exports = config
