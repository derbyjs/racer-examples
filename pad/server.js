var fs = require('fs');
var http = require('http');
var express = require('express');
var handlebars = require('handlebars');
var racerBrowserChannel = require('racer-browserchannel');
var racer = require('racer');
racer.use(require('racer-bundle'));

var backend = racer.createBackend();

app = express();
app
  .use(racerBrowserChannel(backend))
  .use(backend.modelMiddleware());

app.use(function(err, req, res, next) {
  console.error(err.stack || (new Error(err)).stack);
  res.send(500, 'Something broke!');
});

function scriptBundle(cb) {
  // Use Browserify to generate a script file containing all of the client-side
  // scripts, Racer, and BrowserChannel
  backend.bundle(__dirname + '/client.js', function(err, js) {
    if (err) return cb(err);
    cb(null, js);
  });
}
// Immediately cache the result of the bundling in production mode, which is
// deteremined by the NODE_ENV environment variable. In development, the bundle
// will be recreated on every page refresh
if (racer.util.isProduction) {
  scriptBundle(function(err, js) {
    if (err) return;
    scriptBundle = function(cb) {
      cb(null, js);
    };
  });
}

app.get('/script.js', function(req, res, next) {
  scriptBundle(function(err, js) {
    if (err) return next(err);
    res.type('js');
    res.send(js);
  });
});

var indexTemplate = fs.readFileSync(__dirname + '/index.handlebars', 'utf-8');
var renderIndex = handlebars.compile(indexTemplate);
var scriptsTemplate = fs.readFileSync(__dirname + '/scripts.handlebars', 'utf-8');
var renderScripts = handlebars.compile(scriptsTemplate);

app.get('/:roomId', function(req, res, next) {
  var model = req.model;
  // Only handle URLs that use alphanumberic characters, underscores, and dashes
  if (!/^[a-zA-Z0-9_-]+$/.test(req.params.roomId)) return next();
  // Prevent the browser from storing the HTML response in its back cache, since
  // that will cause it to render with the data from the initial load first
  res.setHeader('Cache-Control', 'no-store');

  var $room = model.at('rooms.' + req.params.roomId);
  // Subscribe is like a fetch but it also listens for updates
  $room.subscribe(function (err) {
    if (err) return next(err);
    var room = $room.get();
    // If the room doesn't exist yet, we need to create it
    $room.createNull({content: ''});
    // Reference the current room's content for ease of use
    model.ref('_page.room', $room.at('content'));
    var html = renderIndex({
      room: $room.get('id'),
      text: $room.get('content')
    });
    model.bundle(function(err, bundle) {
      if (err) return next(err);
      var bundleJson = stringifyBundle(bundle);
      html += renderScripts({bundle: bundleJson});
      res.send(html);
    });
  });
});

function stringifyBundle(bundle) {
  return JSON.stringify(bundle)
    // Replace the end tag sequence with an equivalent JSON string to make
    // sure the script is not prematurely closed
    .replace(/<\//g, '<\\/')
    // Replace the start of an HTML comment tag sequence with an equivalent
    // JSON string
    .replace(/<!/g, '<\\u0021');
}

app.get('/', function(req, res) {
  res.redirect('/home');
});

var port = process.env.PORT || 3000;
http.createServer(app).listen(port, function() {
  console.log('Go to http://localhost:' + port);
});
