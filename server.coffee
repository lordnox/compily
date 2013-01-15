fs    = require 'fs'
path  = require 'path'
async = require 'async'

config =
  source: './private'
  destination: './public'
  compiler: path.join __dirname, 'compiler'
  port: 9999
  compilerOptions:
    jade:
      pretty: true

log = (namespace) ->
  (message) ->
    console.log "#{namespace}: #{message}"


reader = (compile, config, next) ->
  readdir = (source, destination, next) ->
    fs.readdir source, (err, files) ->
      return console.log err if err

      working = files.length

      ready = ->
        working--
        if not working
          next err

      files.forEach (filename) ->
        file = path.join source, filename
        dest = path.join destination, filename

        fs.lstat file, (err, stat) ->
          return if err # ignore any errors

          if stat.isDirectory()
            readdir file, dest, ready
          else
            compile file, dest, ready

  readdir config.source, config.destination, next

searchCompilers = (next) ->
  compilers = {}
  fs.readdir config.compiler, (err, files) ->
    return console.error err if err
    files.forEach (file) ->
      if match = file.match /(\w+)\.compiler\.\w+/
        ext = match[1]
        console.log path.join config.compiler, file
        comp = require path.join config.compiler, file
        compilers[ext] = comp (log ext), config.compilerOptions?[ext]

    next null, compilers
###
compilers =
  jade    : (require './jade.compiler') (log "jade"), config.compilerOptions?.jade
  coffee  : (require './coffee.compiler')  (log "coffee"), config.compilerOptions?.coffee
  styl    : (require './stylus.compiler')  (log "stylus"), config.compilerOptions?.stylus
###

startCompilers = (compilers, next) ->
  compile = (source, destination, compiler, next) ->
    compiler.compile source, destination, (err) ->
      console.error err if err
      next()

    timeout = null
    timeoutCompiler = (event) ->
      clearTimeout timeout if timeout
      timeout = setTimeout ->
        compiler.compile source, destination, (err) ->
          console.error err if err

      fs.watch source, timeoutCompiler

  checkCompile = (source, destination, next) ->
    extension = (path.extname source).substr 1
    compile source, destination, compilers[extension], next if extension of compilers
    next()


  reader checkCompile, config, next

startServer = (log, next) ->
  Server = new (require 'node-static').Server config.destination

  require('http').createServer((req, res) ->
    req.on 'end', ->
      log "serving " + req.url
      Server.serve req, res
  ).listen config.port


serverlog = log "server"

serverlog "searching compilers..."
searchCompilers (err, compilers) ->
  return serverlog "abort: " + err if err
  serverlog 'starting compilers...'
  startCompilers compilers, ->
    serverlog 'starting server...'
    startServer serverlog, ->
      serverlog 'server running...'

