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
    ngbp.verbose.log "Starting tasks: " + tasks.join " "
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

Tasks::addFlowTask = ( flow ) ->
  taskName = "flow::#{flow.name}"
  @add taskName, flow.getDependencies(), () ->
    flow.run()
  taskName

module.exports = new Tasks()

