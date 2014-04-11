# Node libraries
Q = require 'q'
FINDUP = require 'findup-sync'
PATH = require 'path'

# ngbo libraries
ngbp = require './../ngbp'

module.exports = ( options ) ->
  ngbp.debug.log "Bootstrapping ngbp..."
  # Store the options provided for system-wide access
  ngbp.options.init options

  # Locate the configuration file and save its path for later use
  configPath = FINDUP ngbp.options( 'configPath' ), { cwd: process.cwd() }

  ngbp.file.readFile( configPath )
  .then ( file ) ->
    ngbp.debug.log "Config information loaded from #{configPath}"
    # Save the config file location for later use
    ngbp.options 'configFile', configPath
    ngbp.options 'projectPath', PATH.dirname( configPath )

    # Parse its contents
    ngbp.util.parseJson file
  , ( err ) ->
    ngbp.fatal "Could not read config file: #{err.toString()}"
  .then ( config ) ->
    ngbp.debug.log "Config loaded."
    # Load the config into ngbp
    ngbp.config.init config

    # TODO(jdm): Read in the package.json, if available
    pkgPath = FINDUP "package.json", { cwd: process.cwd() }
    ngbp.file.readFile( pkgPath )
  , ( err ) ->
    ngbp.fatal "Could not parse config file: #{err.toString()}"
  .then ( file ) ->
    ngbp.debug.log "package.json read from disk."
    ngbp.util.parseJson file
  , ( err ) ->
    ngbp.fatal "Could not load package.json: #{err.toString()}"
  .then ( pkg ) ->
    ngbp.debug.log "package.json loaded to `pkg`."
    ngbp.config "pkg", pkg

    # Load all the plugins
    ngbp.plugins.load()
  , ( err ) ->
    ngbp.fatal "Could not parse package.json: #{err.toString()}"
  .then () ->
    flows = ngbp.flow.all()
    tasks = {}

    # Create tasks for every flow.
    flows.forEach ( flow ) ->
      taskName = ngbp.task.addFlowTask flow

      # Keep track of which flows must run during which meta-tasks
      flow.options.tasks.forEach ( task ) ->
        if not tasks[task]?
          tasks[task] = []

        tasks[task].push taskName
        
    # Now create the meta-tasks with the flow tasks as dependent tasks.
    ngbp.util.mout.object.forOwn tasks, ( deps, task ) ->
      ngbp.task.add task, deps

    ngbp.util.q true
  .then () ->
    # Ensure we have a default task defined, if none has been specified elsewhere
    tasks = ngbp.config( "default" )
    if tasks? and tasks?.length
      ngbp.task.add "default", tasks
    else
      ngbp.task.add "default", () ->
        ngbp.log.warning "There is no default task defined. This is usually handed by plugins or spells."

    ngbp.util.q true

