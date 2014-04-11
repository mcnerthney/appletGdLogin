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

    # TODO(jdm): Process the merge directive, if necessary.

  add: ( priority, name, fn ) ->
    if @usedPriorities.indexOf( priority ) isnt -1
      ngbp.log.warning "Error loading stream '#{name}': multiple tasks in '#{@name}' flow are set to run at #{priority}. There is no guarantee which will run first."
    else
      @usedPriorities.push priority

    @steps.push
      name: name
      priority: priority
      run: fn

    ngbp.debug.log "Added step #{name} to flow #{@name}."
    this

    ###
  addMerge: ( flow, priority ) ->
    @deps.push flow.getTaskName()
    @add "merge::#{flow.name}", priority, () ->
      ES.merge @stream, flow.stream
    this
    ###
      
  watch: ( priority, fn ) ->
    # what to do here?
    this

  run: ( callback ) ->
    steps = ngbp.util.mout.array.sortBy @steps, 'priority'

    # Create the stream by either calling the provided function or reading files from disk.
    sources = @getSources()
    if ngbp.util.isFunction sources
      @stream = sources

      # TODO(jdm): This is completely untested!
      if ngbp.util.isA @stream, "Stream"
        ngbp.fatal "The source function for flow '#{@name}' did not return a stream."
    else
      @stream = ngbp.file.sourceStream sources
    
    steps.forEach ( step ) =>
      ngbp.verbose.log "[#{@name}] Adding stream #{step.name}."
      # TODO(jdm): only pipe to this stream if not disabled
      @stream.pipe step.run( ngbp.config( "tasks.#{step.name}" ) )

    if @options.dest?
      dest = ngbp.config.process @options.dest
      ngbp.verbose.log "[#{@name}] Adding destination stream #{dest}"
      @stream.pipe ngbp.file.destStream( dest )

      #@stream.pipe ES.wait( callback )
    @stream

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

