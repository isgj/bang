{View, TextEditorView} = require 'atom-space-pen-views'
module.exports =
class BangView extends View
  @content: ->
    ## Attributes for the text editor to create
    cmdBuffer =
      mini: true
      placeholderText: 'Enter your command here'
    @div class: 'bang', =>
      @subview 'miniEditor', new TextEditorView(cmdBuffer)
      @div class: 'message', outlet: 'message'

  # Tear down any state and detach
  destroy: ->
    @element.remove()

  getElement: ->
    @element

  setMessage: (text) ->
    @message.text text

  getEditor: ->
    @miniEditor
