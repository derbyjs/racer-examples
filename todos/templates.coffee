exports.page = ({groupName, list, bundle} = {}) ->
  listHtml = (exports.todo todo for todo in list || []).join('')
  """
  <!DOCTYPE html>
  <meta charset="utf-8">
  <title>Racer todos - #{groupName}</title>
  <link rel="stylesheet" href="style.css">
  <form id="head" onsubmit="return false">
    <h1>Todos</h1>
    <div id="add">
      <div id="add-input"><input id="new-todo"></div>
      <input id="add-button" type="submit" value="Add">
    </div>
  </form>
  <div id="dragbox"></div>
  <form id="content" autocomplete="off">
    <ul id="list">#{listHtml}</ul>
  </form>
  """

exports.scripts = (bundle) ->
  json = JSON.stringify(bundle)
    # Replace the end tag sequence with an equivalent JSON string to make
    # sure the script is not prematurely closed
    .replace(/<\//g, '<\\/')
    # Replace the start of an HTML comment tag sequence with an equivalent
    # JSON string
    .replace(/<!/g, '<\\u0021')
  """
  <script async src="/script.js"></script>
  <script id="data-bundle" type="application/json">#{json}</script>
  """

exports.todo = (todo) ->
  unless todo
    return '<li style="display:none"></li>'

  if todo.completed
    completed = 'completed'
    checked = 'checked'
  else
    completed = ''
    checked = ''
  text = (todo.text || '').replace /"/g, '&quot;'
  """
  <li id="#{todo.id}" class="#{completed}">
    <table width="100%">
      <td class="handle" width="0"></td>
      <td width="100%">
        <div class="todo">
          <label><input type="checkbox" #{checked}><i></i></label>
          <input class="text" value="#{text}"><i></i>
        </div>
      </td>
      <td width="0"><button type="button" class="delete">Delete</button></td>
    </table>
  </li>
  """
