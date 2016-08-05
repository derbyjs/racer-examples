fs = require 'fs'
http = require 'http'
coffeeify = require 'coffeeify'
express = require 'express'
racerBrowserChannel = require 'racer-browserchannel'
shareDbMongo = require 'sharedb-mongo'
racer = require 'racer'
racer.use require('racer-bundle')
templates = require './templates'

backend = racer.createBackend {
  db: shareDbMongo('mongodb://localhost:27017/racer-todos')
}

app = express()
app
  .use(express.static('public'))
  .use(racerBrowserChannel(backend))
  .use(backend.modelMiddleware())

app.use (err, req, res, next) ->
  console.error err.stack || (new Error err).stack
  res.send 500, 'Something broke!'

backend.on 'bundle', (browserify) ->
  # Add support for directly requiring coffeescript in browserify bundles
  browserify.transform coffeeify

scriptBundle = (cb) ->
  # Use Browserify to generate a script file containing all of the client-side
  # scripts, Racer, and BrowserChannel
  backend.bundle __dirname + '/client.coffee', {extensions: ['.coffee']}, (err, js) ->
    return cb err if err
    cb null, js
# Immediately cache the result of the bundling in production mode, which is
# deteremined by the NODE_ENV environment variable. In development, the bundle
# will be recreated on every page refresh
if racer.util.isProduction
  scriptBundle (err, js) ->
    return if err
    scriptBundle = (cb) -> cb null, js

app.get '/script.js', (req, res, next) ->
  scriptBundle (err, js) ->
    return next err if err
    res.type 'js'
    res.send js

app.get '/', (req, res) ->
  res.redirect '/home'

app.get '/:groupName', (req, res, next) ->
  groupName = req.params.groupName
  # Only handle URLs that use alphanumberic characters, underscores, and dashes
  return next() unless /^[a-zA-Z0-9_-]+$/.test groupName
  # Prevent the browser from storing the HTML response in its back cache, since
  # that will cause it to render with the data from the initial load first
  res.setHeader 'Cache-Control', 'no-store'

  model = req.model
  $group = model.at "groups.#{groupName}"
  $group.subscribe (err) ->
    return next err if err

    # Create the group and some todos if this is a new group
    unless $group.get()
      id0 = model.add 'todos', {completed: true, text: 'Done already', group: groupName}
      id1 = model.add 'todos', {completed: false, text: 'Example todo', group: groupName}
      id2 = model.add 'todos', {completed: false, text: 'Another example', group: groupName}
      $group.create {todoIds: [id1, id2, id0]}

    model.query('todos', {group: groupName}).subscribe (err) ->
      return next err if err
      # Create a two-way updated list with todos as items
      model.set '_page.groupName', groupName
      model.refList '_page.list', 'todos', $group.at('todoIds')
      html = templates.page model.get('_page')
      # model.bundle waits for any pending model operations to complete and then
      # returns the JSON data for initialization on the client
      model.bundle (err, bundle) ->
        return next err if err
        html += templates.scripts bundle
        res.send html

port = process.env.PORT || 3000;
http.createServer(app).listen port, ->
  console.log 'Go to http://localhost:' + port
