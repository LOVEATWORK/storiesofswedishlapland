### config.coffee template:

config = require './config-defaults'

config.instagram.id = 'myid'
config.instagram.secret = 'morganfreemanmorganfreemanmorganfreeman'

module.exports = config

###

config = {}

config.port = 3005

# points of interest, posts collected in a 5km radius around locations
config.poi = [
  { name: 'Arjeplog',    lat: 66.051505, lng: 17.890054 }
  { name: 'Arvidsjaur',  lat: 65.592077, lng: 19.180283 }
  { name: 'Boden',       lat: 65.825282, lng: 21.665039 }
  { name: 'Gällivare',   lat: 67.13790,  lng: 20.65936  }
  { name: 'Haparanda',   lat: 65.84179,  lng: 24.12762  }
  { name: 'Harads',      lat: 66.08265,  lng: 20.96268  }
  { name: 'Hemavan',     lat: 65.813469, lng: 15.15976  }
  { name: 'Icehotel',    lat: 67.85580,  lng: 20.22528  }
  { name: 'Jokkmokk',    lat: 66.60696,  lng: 19.82292  }
  { name: 'Kalix',       lat: 65.853667, lng: 23.159866 }
  { name: 'Kiruna',      lat: 67.850702, lng: 20.22583  }
  { name: 'Luleå',       lat: 65.5843,   lng: 22.1467   }
  { name: 'Pajala',      lat: 67.212782, lng: 23.367392 }
  { name: 'Piteå',       lat: 65.316418, lng: 21.482391 }
  { name: 'Riksgränsen', lat: 68.42685,  lng: 18.12190  }
  { name: 'Skellefteå',  lat: 64.750244, lng: 20.950917 }
  { name: 'Älvsbyn',     lat: 65.677136, lng: 20.992866 }
  { name: 'Överkalix',   lat: 66.327176, lng: 22.842752 }
  { name: 'Övertorneå',  lat: 66.389725, lng: 23.649496 }
]

config.instagram =
  id: ''
  secret: ''
  # redirect url must match instagram app settings
  redirect: 'http://localhost:' + config.port

module.exports = config
