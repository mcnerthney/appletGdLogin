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
  promise = ngbp.util.q "{}"
  if not configPath?
    ngbp.log.warning "No config file found. Using empty configuration instead."
  else
    ngbp.debug.log "Config found: #{configPath}"
    promise = ngbp.file.readFile( configPath )

  promise
  .then ( file ) ->
    # Save the config file location for later use
    ngbp.options 'configFile', configPath || 'ngbp.json'
    ngbp.options 'projectPath', PATH.dirname( configPath )

    # Parse its contents
    ngbp.util.parseJson file
  , ( err ) ->
    ngbp.fatal "Could not read config file: #{err.toString()}."
  .then ( config ) ->
    ngbp.debug.log "Config loaded."
    # Load the config into ngbp
    ngbp.config.init config

    # Read in the package.json. It's required.
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

    # Flow tasks are tasks that represent single flows.
    flowTasks = {}

    # The meta-tasks are automatically generated based on the configuration of flows.
    metaTasks = {}

    getFlowTaskName = ( flowName ) ->
      "flow::#{flowName}"

    # Gather up the list of flow tasks.
    flows.forEach ( flow ) ->
      taskName = getFlowTaskName flow.name
      flowTasks[taskName] = flow.getDependencies()

    # Now loop through the flows again and add their reverse dependencies (e.g. for a merge). Also,
    # create the flow tasks and gather the data necessary to create meta tasks for every flow task.
    flows.forEach ( flow ) ->
      taskName = getFlowTaskName flow.name

      flow.priorTo.forEach ( task ) ->
        depName = getFlowTaskName task
        if not flowTasks[depName]?
          ngbp.fatal "Unknown task when adding reverse dependency for #{flow.name} - #{depName}"

        flowTasks[depName].push taskName

      # Keep track of which flows must run during which meta-tasks
      flow.options.tasks.forEach ( task ) ->
        if not metaTasks[task]?
          metaTasks[task] = []

        metaTasks[task].push taskName

    # Now create the actual flow-tasks from the information we've collected.
    flows.forEach ( flow ) ->
      taskName = getFlowTaskName flow.name
      deps = flowTasks[taskName]
      ngbp.task.add taskName, deps, () ->
        flow.run()

    # Now create the meta-tasks with the flow tasks as dependent tasks.
    ngbp.util.mout.object.forOwn metaTasks, ( deps, task ) ->
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

