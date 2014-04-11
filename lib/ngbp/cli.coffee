# Node libraries
NOMNOM = require 'nomnom'
PKG = require './../../package.json'
UTIL = require 'util'

# ngbp libraries
ngbp = require './../ngbp'

# Process the command-line options.
options = NOMNOM
.script( 'ngbp' )
.option 'todo',
  list: true
  help: 'The tasks you wish to run. Defaults to \'default\'.'
  position: 0
.option 'help',
  abbr: 'h'
  help: 'Display this help text.'
  flag: true
.option 'version',
  abbr: 'V'
  help: 'Print the ngbp version.'
  flag: true
  callback: () ->
    # TODO(jdm): print available tasks for completion scripts
    "ngbp v#{PKG.version}"
.option 'verbose',
  abbr: 'v'
  help: 'Verbose mode. A lot more helprmation output.'
  flag: true
.option 'debug',
  abbr: 'd'
  help: 'Enable debugging mode for tasks that support it.'
  flag: true
.option 'stack',
  help: 'Print a stack trace when exiting with a warning or fatal error.'
  flag: true
.option 'flows',
  abbr: 'f'
  help: 'Print out the list of defined flows.'
  flag: true
.option 'tasks',
  help: 'Print out the list of available tasks.'
  flag: true
.option 'configPath',
  abbr: 'c'
  help: 'The JSON configuration file to use. Defaults to `ngbp.json` and will find upward.'
  default: 'ngbp.json'
  full: 'config'
.option 'plugins',
  help: 'Load plugins from the specified directory.'
  list: true
.option 'conf',
  help: 'Get a configuration value.'
.option 'set',
  abbr: 's'
  help: 'Set or change a configuration value. Must be used with --get. Use --write to save to ngbp.json.'
.option 'prevent',
  abbr: 'p'
  help: 'A comma-separated list of tasks to prevent from running. Use --write to save to ngbp.json.'
  list: true
.option 'allow',
  abbr: 'a'
  help: 'A comma-separated list of tasks to allow, overwriting whether they are prevented. Use ' +
    '--write to save to ngbp.json, if necessary.'
  list: true
.option 'inject',
  abbr: 'i'
  help: 'Inject a task into the build process using the format task@hook#priority. E.g. ' +
    '"mytask:subtask@prebuild#20". This option can be repeated to inject multiple tasks. Use ' +
    '--write to save to ngbp.json.'
  list: true
.option 'injectWatch',
  help: 'Inject a task into the watch process using the format task@glob#priority. E.g. ' +
    '"mytask:subtask@app.js#20". This option can be repeated to inject multiple tasks. Use ' +
    '--write to save to ngbp.json.'
  full: 'inject-watch'
  list: true
.option 'write',
  abbr: 'w'
  help: 'Write any configuration changes to `ngbp.json`, such as task preventions.'
  flag: true
.option 'raw',
  help: 'When printing configuration values, do not process them as templates first. This will ' +
    'show the values as they were defined, rather than how they will appear during runtime.'
  flag: true
.option 'user',
  abbr: 'u'
  help: 'Restrict configuration commands to your local ngbp configuration (ngbp.json).'
  flag: true
.option 'coffee',
  help: 'When creating a new ngbp app, scaffold the Gruntfile in CoffeeScript instead of JavaScript.'
  flag: true
.option 'appName',
  help: 'When creating a new ngbp app, the name of the app to create.'
  full: 'app-name'
.option 'appVersion',
  help: 'When creating a new ngbp app, the version of the app to create.'
  full: 'app-version'
.option 'appAuthor',
  help: 'When creating a new ngbp app, the author of the app to create.'
  full: 'app-author'
.parse()

###
# Start the CLI, people!
###
cli = () ->
  runDefaultTasks = true

  # TODO(jdm): check if we need to init

  # With any of these options, we needn't necessarily run the default tasks.
  if options.flows or options.tasks or options.write
    runDefaultTasks = false

  # If the user is getting a value - but not setting it - we needn't necessarily run the default
  # task.
  if options.conf and ! options.set
    runDefaultTasks = false

  # Tasks were specified, we don't need to run the default ones either
  if options.todo?.length > 0
    runDefaultTasks = false

  ngbp.bootstrap( options )
  .then () ->
    # Handle the command line options

    # TODO(jdm): process prevent
    # if options.prevent
    #   options.prevent.forEach TASK.preventTask

    # TODO(jdm): process allow
    # if options.allow
    #   options.allow.forEach TASK.allowTask

    # TODO(jdm): process plugins

    # TODO(jdm): process set

    # If requested, print out a configuration value.
    if options.conf?
      option = UTIL.inspect ngbp.config( options.conf ),
        colors: true
      ngbp.log.writeln "\n#{options.conf} = #{option}"

    # TODO(jdm): process inject
    # if options.inject
    #   options.inject.forEach ( task ) ->
    #     TASK.inject UTIL.parseTaskString( task )

    # TODO(jdm): process injectWatch
    # if options.injectWatch
    #   options.injectWatch.forEach ( task ) ->
    #     TASK.inject UTIL.parseTaskString( task, true )

    # Print out a task list, if requested.
    if options.tasks?
      ngbp.help.printTaskTable()

    # Print out a flows list, if requested.
    if options.flows?
      ngbp.help.printFlowsTable()

    # Number One, make it so!
    if runDefaultTasks or options.todo?.length > 0
      ngbp.engage options.todo
  .catch ( err ) ->
    ngbp.fatal err

# Our only export is the cli function
module.exports = cli


