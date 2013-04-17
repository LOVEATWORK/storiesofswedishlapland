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
  {lat: 67.85580, lng: 20.22528, name: 'icehotel'}
  {lat: 65.84179, lng: 24.12762, name: 'haparanda'}
  {lat: 66.60696, lng: 19.82292, name: 'jokkmokk'}
  {lat: 68.42685, lng: 18.12190, name: 'gränsen'}
  {lat: 67.13790, lng: 20.65936, name: 'gällivare'}
  {lat: 66.08265, lng: 20.96268, name: 'harads'}
]

config.instagram =
  id: ''
  secret: ''
  # redirect url must match instagram app settings
  redirect: 'http://localhost:' + config.port

module.exports = config
