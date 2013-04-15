
module.exports = (env, callback) ->
  env.registerContentPlugin 'data', 'data/**', env.plugins.StaticFile
  callback()
