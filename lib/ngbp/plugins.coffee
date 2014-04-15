# Node libraries
PATH = require 'path'

# ngbp libraries
ngbp = require './../ngbp'

plugins = module.exports = {}

pluginRegistry = []

plugins.load = () ->
  ngbp.debug.log "Loading all plugins..."
  plugins.loadNpmPlugins()
  .then () ->
    # Load configuration-defined plugins
    pluginPaths = ngbp.config 'plugins'
    if not pluginPaths? or pluginPaths.length is 0
      ngbp.util.q true
    else
      ngbp.util.promise ( deferred ) ->
        ngbp.util.each pluginPaths, ( path, callback ) ->
          plugins.loadPlugins( PATH.join( ngbp.options( 'projectPath' ), path ) )
          .then () ->
            callback()
          , ( err ) ->
            callback err
        , ( err ) ->
          if err?
            deferred.reject err
          else
            deferred.resolve true

# TODO(jdm): inject tasks from config

plugins.loadPlugins = ( plugin_dir, config ) ->
  ngbp.verbose.log "Loading plugins from path '#{plugin_dir}'"

  if pluginRegistry.indexOf( plugin_dir ) isnt -1
    ngbp.log.warning "#{plugin_dir} has already been loaded. Skipping it for now."
    ngbp.util.q true
  else if not ngbp.file.pathExistsSync plugin_dir
    ngbp.log.fatal "Plugin directory #{plugin_dir} doesn't exist."
  else
    # Read in the configuration from the provided metadata, if provided.
    if config
      ngbp.debug.log "Loading configurations for: #{plugin_dir}"
      ngbp.config.merge config

    # Locate all the plugin files.
    ngbp.file.glob( PATH.join( plugin_dir, '*.{js,coffee}' ) )
    .then ( files ) ->
      if not files? or files.length is 0
        ngbp.log.warning "No plugins found in path #{plugin_dir}"
        ngbp.util.q true
      else
        ngbp.util.promise ( deferred ) ->
          ngbp.util.each files, ( file, callback ) ->
            try
              fn = require file

              if ngbp.util.typeOf( fn ) is 'Function'
                fn.call ngbp, ngbp
                callback()
              else
                ngbp.log.warning "#{plugin_dir} doesn't export a function."
                callback()
            catch err
              callback( err )
          , ( err ) ->
            if err?
              deferred.reject err
            else
              deferred.resolve true

plugins.loadNpmPlugins = () ->
  modules_dir = PATH.resolve 'node_modules'

  # Stream all the package files
  ngbp.file.glob( PATH.join( modules_dir, '/*/package.json' ) )
  .then ( files ) ->
    if not files?.length
      ngbp.debug.log "There were no NPM packages to attempt to load."
      return ngbp.util.q true

    ngbp.util.promise ( deferred ) ->
      ngbp.util.each files, ( file, callback ) ->
        contents = ngbp.file.readFileSync( file )
        pkg = ngbp.util.parseJsonSync( contents )
        if pkg?.keywords? and pkg.keywords.indexOf( 'ngbpplugin' ) isnt -1
          ngbp.verbose.log "Found ngbp plugin #{pkg.name}"
          # TODO(jdm): handle ngbpcollections
          
          plugins.loadPlugins( PATH.join( modules_dir, pkg.name, 'plugins' ), pkg?.ngbp )
          .then () ->
            callback()
          , ( err ) ->
            callback err
        else
          callback()
      , ( err ) ->
        if err?
          deferred.reject err
        else
          deferred.resolve true

