# Node libs
Table = require 'cli-table'

# ngbp
ngbp = require '../ngbp'

help = module.exports = {}

help.printTaskTable = () ->
  ngbp.log.header "Defined Tasks"
  table = new Table
    head: [ 'Task Name', 'Dependencies' ]

  ngbp.task.getTasks().forEach ( task ) ->
    table.push [ task.name, task.dep.join( ", " ) ]

  ngbp.log.writeln table.toString()

help.printFlowsTable = () ->
  ngbp.log.header "Defined Flows"

  ngbp.flow.all().forEach ( flow ) ->
    # Get the name of the source(s)
    source = flow.getSources()
    if ngbp.util.isFunction source
      source = "Function"
    else
      # This could be an array or arrays, so we flatten it and then comma-dilineate it.
      source = source.join ", "

    # Get the name of the dest
    if flow.options.merge?
      dest = "Merge to #{flow.options.merge.to} at #{flow.options.merge.priority}"
    else
      dest = ngbp.config.process flow.options.dest

    # Get the list of streams
    streams = ngbp.util.mout.array.pluck( flow.getStreams(), 'name' ).join ", "

    ngbp.log.subheader flow.name
    table = new Table
      colWidths: [ 10, 87 ]
      colAligns: [ 'right', 'left' ]
      chars:
        'top': ""
        'top-mid': ""
        'top-left': ""
        'top-right': ""
        'bottom': ""
        'bottom-mid': ""
        'bottom-left': ""
        'bottom-right': ""
        'left': ""
        'left-mid': ""
        'mid': ""
        'mid-mid': ""
        'right': ""
        'right-mid': ""
        'middle': ""

    table.push
      Source: source
    table.push
      Dest: dest
    table.push
      Streams: streams

    ngbp.log.writeln table.toString()

