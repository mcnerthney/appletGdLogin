# The module to be exported.
ngbp = module.exports = {}

# Get the version number
ngbp.version = require( './../package.json' ).version

# Expose internal ngbp libs.
nRequire = ( name ) ->
  ngbp[ name ] = require './ngbp/' + name

# Expose module functions globally.
nExpose = ( o, fn, newFn ) ->
  if ngbp.util.typeOf( o[ fn ] ) is 'Function'
    ngbp[ newFn or fn ] = o[ fn ].bind o
  else
    ngbp[ newFn or fn ] = o[ fn ]

# Export some NGBP libs.
# TODO(jdm): Port these to coffee and streams
#nRequire 'scaffold'
#nRequire 'bower'

# Gruntless, Good to Go
nRequire 'task'
nRequire 'help'
nRequire 'util'
nRequire 'plugins'
nRequire 'config'
nRequire 'cli'
nRequire 'log'
nRequire 'options'
nRequire 'flow'
nRequire 'bootstrap'
nRequire 'file'

# Expose some methods from the included libs directly under the ngbp namespace.
nExpose ngbp.task, 'engage'
nExpose ngbp.log, 'verbose'
nExpose ngbp.log, 'debug'
nExpose ngbp.log, 'fatal'
nExpose ngbp.config, 'user', 'userConfig'

