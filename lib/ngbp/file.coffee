VFS = require 'vinyl-fs'
FS = require 'fs'
PATH = require 'path'
Q = require 'q'
rimraf = Q.denodeify require( 'rimraf' )

# Exported module
file = module.exports = {}

# Filesystem wrappers
file.readFile = Q.denodeify FS.readFile
file.writeFile = Q.denodeify FS.writeFile
file.pathExists = Q.denodeify FS.exists
file.readFileSync = FS.readFileSync
file.writeFileSync = FS.writeFileSync
file.pathExistsSync = FS.existsSync

# Rimraf
file.rimraf = ( target ) ->
  cwd = process.cwd()
  relative = PATH.relative cwd, target

  # For the love of all that is holy, do not delete the CWD or anything outside it!
  if relative is ''
    ngbp.fatal "I will not delete the current working directory."
  else if relative.substr( 0, 2 ) is '..'
    ngbp.fatal "I will not delete anything outside the current working directory."
    
  rimraf( target )
  .catch ( err ) ->
    ngbp.fatal "I couldn't delete #{target}: #{err}"

# Globbing
file.glob = Q.denodeify require( 'glob' )
file.globStream = require( 'glob-stream' ).create

# Stream Creation
file.sourceStream = VFS.src
file.destStream = VFS.dest

