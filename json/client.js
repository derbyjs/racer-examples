var data = JSON.parse(document.scripts[0].getAttribute('data-bundle'));
var model = require('racer').createModel(data);
window.MODEL = model

var pre = document.getElementById('json');
var editor = document.getElementById('editor');

model.on('change', '_page.room', function(newValue, previous, passed) {
  console.log("changed!", arguments)
  var data = model.get('_page.room')
  var text = JSON.stringify(data, null, 2)
  pre.innerHTML = text

  if(!passed.$remote) return console.log("local");
  editor.value = text;
});

function onInput() {
  var value = editor.value;
  try {
    var json = JSON.parse(value);
  } catch(e) {
    console.log("invalid json")
    return;
  }
  var previous = model.get("_page.text") || '';

  if (value != previous) {
    model.set("_page.room", json)
  }
}

editor.addEventListener('input', function() {
  setTimeout(onInput, 0);
}, false);

