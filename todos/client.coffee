racer = require 'racer'
templates = require './templates'
require './vendor/jquery-1.9.1.min'
require './vendor/jquery-ui-1.10.3.custom.min.js'

$ ->
  data = JSON.parse document.scripts[0].getAttribute('data-bundle')
  model = racer.createModel data

  list = $('#list')
  listModel = model.at '_page.list'

  ## Update the DOM when the model changes ##

  listModel.on 'change', '*.completed', (index, value) ->
    item = list.children().eq(index)
    item.toggleClass 'completed', value
    item.find('[type=checkbox]').prop 'checked', value

  listModel.on 'change', '*.text', (index, value) ->
    item = list.children().eq(index).find('.text')
    item.val value unless item.val() == value

  listModel.on 'change', '*', (index, value) ->
    list.children().eq(index).replaceWith templates.todo(value)

  listModel.on 'insert', (index, values) ->
    html = (templates.todo value for value in values).join ''
    target = list.children().eq(index)
    if target.length
      target.before html
    else
      list.append html

  listModel.on 'remove', (index, removed) ->
    list.children().slice(index, index + removed.length).remove()

  listModel.on 'move', (from, to, howMany, passed) ->
    # If caused by sortable, it will have already moved the element
    return if passed.sortable
    moved = list.children().slice from, from + howMany
    index = if from > to then to else to + howMany
    target = list.children().eq index
    if target.length
      target.before moved
    else
      list.append moved

  ## Update the model in response to DOM events ##

  newTodo = $('#new-todo')
  $('#head').on 'submit', ->
    text = newTodo.val()
    # Don't add a blank todo
    return unless text
    newTodo.val ''
    # Insert the new todo before the first completed item
    items = listModel.get()
    if items
      for todo, i in items
        break if todo?.completed
    newTodoId = model.add 'todos',
      completed: false
      text: text
    listModel.insert i || 0, model.root.get "todos.#{newTodoId}"

  eventIndex = (e) ->
    item = $(e.target).parents('li')
    return list.children().index(item)

  list.on 'change', '[type=checkbox]', (e) ->
    index = eventIndex e
    listModel.set index + '.completed', e.target.checked
    # Move the item to the bottom if it was checked off
    listModel.move index, -1 if e.target.checked

  list.on 'input', '.text', (e) ->
    listModel.set eventIndex(e) + '.text', e.target.value

  list.on 'click', '.delete', (e) ->
    listModel.remove eventIndex(e)

  from = null
  list.sortable
    handle: '.handle'
    axis: 'y'
    containment: '#dragbox'
    start: (e, ui) ->
      item = ui.item[0]
      from = list.children().index(item)
    update: (e, ui) ->
      item = ui.item[0]
      to = list.children().index(item)
      # model.pass() will pass an extra argument along to events resulting from
      # mutations. It is often used to ignore events when something has already
      # been updated and to avoid infinite loops
      listModel.pass(sortable: true).move from, to
