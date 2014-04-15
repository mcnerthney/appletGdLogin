TPL = require 'lodash.template'
ES = require 'event-stream'
VFS = require 'vinyl-fs'
StreamQueue = require 'streamqueue'

# ngbp
ngbp = require './../ngbp'

# Exported Module
streams = module.exports = {}

# Convert a stream to a function.
streams.map = ES.map

# A queue to merge streams.
streams.MergeQueue = StreamQueue

# A stream to process the contents as a template.
streams.template = ( dest ) ->
  data = ngbp.config( "template-data" ) or {}
  data.ngbp = ngbp

  streams.map ( file, callback ) ->
    return if file.isNull()

    data.filepath = ngbp.file.joinPath dest, file.relative
    contents = ngbp.util.template file.contents.toString(), data
    file.contents = new Buffer contents

    callback null, file

# File Stream Creation
streams.fileReadStream = ( globs, options ) ->
  options = ngbp.config.process( options ) if options?
  VFS.src globs, options

streams.fileWriteStream = ( path, options ) ->
  options = ngbp.config.process( options ) if options?
  VFS.dest path, options

