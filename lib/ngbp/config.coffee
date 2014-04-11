# node libs
MOUT = require 'mout'
Q = require 'q'
FS = require 'fs'
FINDUP = require 'findup-sync'
MERGE = require 'deepmerge'
GRUNT = require 'grunt'

# ngbp libs
ngbp = require './../ngbp'

###
# Default ngbp options
###
_defaultConfig =
  # Overwriteable glob patterns tasks can reference or use to make flows.
  globs: {}

  # Overwriteable directories build tasks can reference.
  paths: {}

  # Directories to look for plugins
  plugins: []
   
  # Tasks to prevent from running.
  prevent: []

  # Tasks to inject into one of the flows.
  inject: []

  # The default tasks to run when none are specified.
  default: []

  myval: "Hello!"

###
# The current ngbp-wide configuration.
###
_config = {}

config = module.exports = ( key, val, merge ) ->
  if key
    if val
      if merge
        merge = {}
        MOUT.object.set merge, key, val
        config.merge merge
      else
        MOUT.object.set _config, key, val

    return config.process MOUT.object.get( _config, key )
  else
    return config.process MOUT.object.merge( {}, _config )

###
# Get the user-defined ngbp configuration.
###
config.init = ( conf ) ->
  _userConfig = conf
  _config = MERGE _defaultConfig, conf

###
# Process every property of an object recursively as a template.
# Ripped from Grunt nearly directly.
###
propStringTmplRe = /^<%=\s*([a-z0-9_$]+(?:\.[a-z0-9_$]+)*)\s*%>$/i
config.process = ( raw ) ->
  # recurse will call the given for every non-object, non-array property of the given
  # object, however deep it has to go to do it.
  val = ngbp.util.forEveryProperty raw, ( value ) ->
    if not value?
      return value

    # We cannot process a non-string value (e.g. a number or a stream or whatnot) as a template, so
    # just return it.
    if ngbp.util.typeOf( value ) isnt 'String'
      return value

    # If possible, access the specified property via config.get, in case it
    # doesn't refer to a string, but instead refers to an object or array.
    matches = value.match /^<%=\s*([a-z0-9_$]+(?:\.[a-z0-9_$]+)*)\s*%>$/i
    if matches
      result = config.get matches[ 1 ]

      # If the result retrieved from the config data wasn't null or undefined,
      # return it.
      if result?
        return result

    # Process the string as a template.
    return ngbp.util.template value, _config

###
# Merge a config object into the current configuration.
###
config.merge = ( conf ) ->
  _config = MERGE _config, conf

config.set = ( key, val ) ->
  MOUT.object.set _config, key, val

config.get = ( key ) ->
  config.process MOUT.object.get( _config, key )

config.getRaw = ( key ) ->
  if key
    MOUT.object.get _config, key
  else
    MOUT.object.merge {}, _config

###
# The user's configuration, containing only those variables set of manipulated by the user. All of
# these are also in _config, but this is what should be synchronized to ngbp.json.
###
_userConfig = {}

config.user = ( key, val, merge ) ->
  if key
    if val
      if merge
        merge = {}
        MOUT.object.set merge, key, val
        config.merge merge
      else
        MOUT.object.set _config, key, val

      # Regardless of whether it's a merge, we still need to sync the changes.
      _syncUserChanges()

    return config.process MOUT.object.get( _config, key )
  else
    return config.process MOUT.object.merge( {}, _config )

###
# Everything that needs to be done once the configuration is changed. e.g. sync with grunt.
###
_syncUserChanges = () ->
  config.merge _userConfig

config.user.get = ( key ) ->
  config.process MOUT.object.get( _userConfig, key )

config.user.getRaw = ( key ) ->
  MOUT.object.get _userConfig, key

###
# Merge a config object into the user configuration.
###
config.user.merge = ( conf ) ->
  _userConfig = MERGE _userConfig, conf
  config.merge _userConfig
  _syncUserChanges()

###
# Set a configuration item on the user's configuration.
###
config.user.set = ( key, val ) ->
  MOUT.object.set _userConfig, key, val
  MOUT.object.set _config, key, val
  _syncUserChanges()

###
# Write the user configuration to file or, if requested, the entire ngbp configuration.
###
config.write = ( includeSystem ) ->
  if includeSystem
    conf = _config
  else
    conf = _userConfig

  ngbp.util.stringifyJson conf, true
  .then ( json ) ->
    # write to ngbp.json
    return ngbp.file.writeFile OPTIONS( 'configPath' ), contents
  , ( err ) ->
    LOG.fatal "Could not stringify JSON for config: #{err.toString()}"

