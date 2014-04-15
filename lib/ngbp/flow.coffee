# Node libraries
MOUT = require 'mout'
ES = require 'event-stream'

# ngbp
ngbp = require './../ngbp'

# Flows currently registered
flows = {}

# Tasks during which flows would like to run.
definedTasks = []

# Priority range
minPriority = 1
maxPriority = 100

class Flow
  constructor: ( @name, @options ) ->

    # Set up some instance variables we'll need later on.
    @steps = []
    @usedPriorities = []
    @priorTo = []

    # Set the array of tasks during which this flow needs to run.
    @options.tasks ?= []
    @options.tasks = [ @options.tasks ] if ngbp.util.typeOf( @options.tasks ) isnt 'Array'

    # Ensure the source is valid.
    if not @options.source?
      throw new Error "Flow '#{@name}' has no source. It can't do anything if it starts with nothing."

    if ngbp.util.isString @options.source
      @options.source = [ @options.source ]

    if not ngbp.util.isFunction( @options.source ) and not ngbp.util.isArray( @options.source )
      throw new Error "Flow '#{@name}' has an invalid source. It must be a string path, an array of string paths, or a function that returns a stream."

    if not ngbp.util.isFunction( @options.source ) and not ngbp.util.isArray( @options.source )
      throw new Error "Invalid source for flow '#{@name}'; expected String, Array, or Function."

    # Ensure the destination is valid.
    if @options.dest and not ngbp.util.isString @options.dest
      throw new Error "Flow '#{@name}' has an invalid destination. It must be a string path."

    # Load up the passed-in dependencies, if necessary.
    if ngbp.util.isString @options.depends
      @options.depends = [ @options.depends ]

    if @options.depends?
      @deps = @options.depends
    else
      @deps = []

    # Create a clean task if requested.
    if @options.clean and @options.dest?
      task = ngbp.task.addCleanTask @name, ngbp.config.process( @options.dest )
      @deps.push task

    # Create pre- and post-queues for task injection.
    @queues =
      pre: new ngbp.streams.MergeQueue
        objectMode: true
      post: new ngbp.streams.MergeQueue
        objectMode: true

    # Pre-process the merge directive.
    if @options.merge?
      @merge = {}
      [ @merge.type, @merge.target, @merge.queue ] = @options.merge.split "::"
      
      if not @merge.type?
        ngbp.fatal "[#{@name}] You must provide a type as part of the merge directive."

      # In the future, more merge types will be accepted.
      if @merge.type isnt "queue"
        ngbp.fatal "[#{@name}] Unknown merge type '#{type}'."

      if not @merge.target?
        ngbp.fatal "[#{@name}] You must provide a target as part of the merge directive."

      # register dependency with other flow
      @priorTo.push @merge.target

  add: ( priority, name, fn ) ->
    if @usedPriorities.indexOf( priority ) isnt -1
      ngbp.log.warning "Error loading stream '#{name}': multiple tasks in '#{@name}' flow are set to run at #{priority}. There is no guarantee which will run first."
    else
      @usedPriorities.push priority

    @steps.push
      name: name
      priority: priority
      run: fn

    ngbp.debug.log "[#{@name}] Added stream #{name}"
    this

    ###
  addMerge: ( flow, priority ) ->
    @deps.push flow.getTaskName()
    @add "merge::#{flow.name}", priority, () ->
      ES.merge @stream, flow.stream
    this
    ###
      
  watch: ( priority, fn ) ->
    # TODO(jdm): what to do here?
    this

  run: ( callback ) ->
    ngbp.verbose.log "[#{@name}] Running..."
    steps = ngbp.util.mout.array.sortBy @steps, 'priority'

    # Create the stream by either calling the provided function or reading files from disk. Then
    # add it into the pre queue with anything another flow may have merged here.
    sources = @getSources()
    if ngbp.util.isFunction sources
      sources = sources()

      # TODO(jdm): This is completely untested!
      if ngbp.util.isA sources, "Stream"
        ngbp.fatal "[#{@name}] The source function did not return a stream."

      @queues.pre.queue @stream
    else
      if sources.length is 0 and @queues.pre.length is 0
        ngbp.log.warning "[#{@name}] Got empty globbing pattern. Skipping flow."
        return

      @queues.pre.queue ngbp.streams.fileReadStream( sources, @options.source_options )

    # The pre-queue is now completely done.
    @stream = @queues.pre.done()
    
    steps.forEach ( step ) =>
      ngbp.verbose.log "[#{@name}] Adding stream #{step.name}."
      # Only pipe to this stream if not disabled
      if ngbp.task.isPrevented step.name
        ngbp.verbose.log "[#{@name}] Stream #{step.name} prevented from running."
      else
        @stream = @stream.pipe step.run( ngbp.config( "tasks.#{step.name}" ) )

    # Add it into the post queue with anything another flow may have merged here.
    @stream = @queues.post.queue( @stream ).done()

    if @merge?
      ngbp.verbose.log "[#{@name}] Merging into #{@merge.target}@#{@merge.queue}"
      flow( @merge.target ).addToQueue @merge.queue, @stream

      # We must return nothing so the task manager does NOT wait.
      return
    else if @options.dest?
      dest = ngbp.config.process @options.dest
      ngbp.verbose.log "[#{@name}] Adding destination stream #{dest}"
      @stream = @stream.pipe ngbp.streams.fileWriteStream( dest, @options.dest_options )

      # We must return the stream so the task manager knows to wait.
      return @stream

  shouldBeCleaned: () ->
    @options.clean? and @options.clean

  getDependencies: () ->
    @deps

  getStreams: () ->
    ngbp.util.mout.array.sortBy @steps, 'priority'

  getSources: () ->
    unless ngbp.util.isFunction @options.source
      ngbp.util.mout.array.flatten ngbp.config.process( @options.source )
    else
      @options.source

  addToQueue: ( queue, stream ) ->
    ngbp.fatal "[#{@name}] The queue '#{queue}' does not exist!" if not @queues[queue]?
    @queues[queue].queue stream

module.exports = flow = ( name, options ) ->
  if flows[ name ]?
    if options?
      ngbp.fatal "The flow '#{name}' already exists."
      # TODO(jdm): Add ability to merge or re-define an existing stream.
  else
    flows[ name ] = new Flow( name, options )

  flows[ name ]

###
# Get all defined flows.
###
flow.all = () ->
  MOUT.object.values flows

