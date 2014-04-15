# node libraries
Orchestrator = require 'orchestrator'

# ngbp libs
ngbp = require './../ngbp'

# The default tasks to run
defaultTasks = [ 'default' ]

class Tasks extends Orchestrator

Tasks::engage = ( t ) ->
  tasks = t ? []

  if not tasks? or tasks.length is 0
    tasks = defaultTasks

  tasks.forEach ( task ) =>
    if not @hasTask task
      ngbp.fatal "Unknown task: #{task}"

  if tasks.length is 0
    ngbp.log.log "There are no tasks to run."
  else
    ngbp.log.subheader "Starting tasks: " + tasks.join " "
    start = process.hrtime()

    # The last argument is a callback.
    tasks.push () ->
      elapsed = process.hrtime( start )
      s = elapsed[0]
      ms = elapsed[1] / 1000000
      ngbp.log.subheader "Completed tasks in #{s}s #{ms.toFixed(0)}ms."

    @start.apply( @, tasks )

Tasks::getTasks = () ->
  tasks = ngbp.util.mout.object.values @tasks

  # For each task, sort the dependencies
  tasks.forEach ( task ) =>
    deps = []
    try
      @sequence @tasks, task.dep, deps
      task.dep = deps
    catch err
      if err?
        if err.missingTask?
          ngbp.log.fatal "Unknown task: #{err.missingTask}"
          @.emit "task_not_found",
            message: err.message
            task:err.missingTask
            err: err
        if err.recursiveTasks?
          ngbp.log.fatal "Recursive tasks: #{err.recursiveTasks}"
          @.emit "task_recursion",
            message: err.message
            recursiveTasks:err.recursiveTasks
            err: err

  tasks

Tasks::addCleanTask = ( name, target ) ->
  taskName = "clean::#{name}"
  @add taskName, () ->
    ngbp.verbose.log "[#{name}] Cleaning #{target}"
    ngbp.file.rimraf target
  taskName

Tasks::isPrevented = ( task ) ->
  allowed = false
  allow = ngbp.config.get( "allow" ) or []
  allow.forEach ( t ) ->
    allowed = true if task is t

  return false if allowed

  prevented = false
  prevent = ngbp.config.get( "prevent" ) or []
  prevent.forEach ( t ) ->
    prevented = true if task is t

  if prevented then true else false

module.exports = new Tasks()

