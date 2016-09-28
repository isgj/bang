{$, TextEditorView, View}  = require('atom-space-pen-views')
execSync = require('child_process').execSync
exec = require('child_process').exec
{CompositeDisposable} = require 'atom'
BangCommands = require './bang-commands'
BangView = require './bang-view'

module.exports = Bang =
  config:
    numberOfCommandsToSave:
      type: 'integer'
      default: 100
      minimum: 1
      maximum: 1000
    doNotAutoHideNotifications:
      type: 'boolean'
      default: true

  bangView: null
  bangCommands: null
  modalPanel: null
  subscriptions: null
  # The variable to check in which mode the view is running
  # false: the output of the command will edit the text
  # true: the output will be shown in a notification
  dryCmd: false

  activate: (state) ->
    # Restore previous state
    @bangCommands = atom.deserializers.deserialize(state.bangCommandsState)

    @bangView = new BangView()
    @modalPanel = atom.workspace.addModalPanel(item: @bangView.element, visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register commands that toggles this view
    @subscriptions.add atom.commands.add 'atom-text-editor', 'bang:edit-text', => @toggle()
    @subscriptions.add atom.commands.add 'atom-workspace', 'bang:run-a-command', =>
      @dryCmd = true
      @toggle()

    # Register commands when we are typing
    @miniEditor = @bangView.getEditor()
    @subscriptions.add atom.commands.add @miniEditor.element, 'bang:confirm', => @confirm()
    @subscriptions.add atom.commands.add @miniEditor.element, 'bang:cancel', => @close()
    @subscriptions.add atom.commands.add @miniEditor.element, 'bang:next', => @next('n')
    @subscriptions.add atom.commands.add @miniEditor.element, 'bang:prev', => @next('p')
    @subscriptions.add atom.commands.add @miniEditor.element, 'bang:complete', => @complete()
    @miniEditor.on 'blur', => @close()

  # The package is being closed
  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @bangView.destroy()

  # Serialize the list of commands
  serialize: ->
    bangCommandsState: @bangCommands.serialize()

  # Toggle the panel
  toggle: ->
    if @modalPanel.isVisible()
      @close()
    else
      @open()

  # Close the panel
  close: ->
    return unless @modalPanel.isVisible()
    miniEditorFocused = @miniEditor.hasFocus()
    @miniEditor.setText('')
    @modalPanel.hide()
    @bangCommands.next = 0
    @restoreFocus() if miniEditorFocused

  # This method id fired when we press ENTER
  confirm: ->
    cmd = @miniEditor.getText().trim()
    @bangCommands.addCommand cmd
    editor = atom.workspace.getActiveTextEditor()
    @close()
    # The edit-text needs an active text editor
    if not @dryCmd
      return unless editor?
    if editor.getPath()
      # We set the current working directory like this
      # only if the file is saved in the disk
      cwdLength = editor.getPath().length - editor.getTitle().length
      cwd = editor.getPath()[0...cwdLength]
    else
      # A file has no name :)
      # it's a new buffer
      cwd = @referenceDir()
    # The text to give as input to the command
    input = editor?.getSelectedText()
    dirMessage = cwd + ':$ ' + cmd
    missNote = atom.config.get 'bang.doNotAutoHideNotifications'
    # Run an asynchronous process if there
    # is no input and don't have to edit the text
    if @dryCmd and not input.length
      exec cmd, cwd: cwd, (error, stdout, stderr) =>
        if error
          dirMessage += '\n' + stderr
          atom.notifications.addWarning('Attention', {detail: dirMessage, dismissable: missNote})
          @dryCmd = false
          return
        msgTitle = cwd + ':$ ' + cmd
        atom.notifications.addSuccess(msgTitle, {detail: stdout, dismissable: missNote})
        @dryCmd = false
        return
      return
    try
      output = execSync cmd, {cwd, input: input, timeout: 5e3}
      output = output.toString()
    catch e
      dirMessage += '\n' + e.stderr.toString()
      atom.notifications.addWarning('Attention', {detail: dirMessage, dismissable: missNote})
      @dryCmd = false
      return
    if output.length
      # Check where to put the output of cmd
      if @dryCmd
        atom.notifications.addSuccess(dirMessage, {detail: output, dismissable: missNote})
        @dryCmd = false
      else
        range = editor.getSelectedBufferRange()
        editor.setTextInBufferRange range, output

  # Show the panel and get focus
  open: ->
    return if @modalPanel.isVisible()
    if editor = atom.workspace.getActiveTextEditor()
      @storeFocusedElement()
      @modalPanel.show()
      if editor.getSelectedText()?.length
        @bangView.setMessage "Filter the selected text with your command"
      else
        @bangView.setMessage "Bang a command"
      @miniEditor.focus()

  # Get a suggestion from @bangCommands.matchList
  # UP arrow =>
  #    input: n
  #    output: cycle from the most recent to the most previously command direction
  # DOWN arrow =>
  #    input: p
  #    output: cycle form the most previously to the most recent command direction
  next: (i) ->
    range = @miniEditor.getModel().getSelectedBufferRange()
    @miniEditor.getModel().setTextInBufferRange range, ""
    word = @miniEditor.getText().trim()
    suggestion = @bangCommands.getNextCMD word, i
    if suggestion isnt null
      range = @miniEditor.getModel().setTextInBufferRange range, suggestion
      @miniEditor.getModel().addSelectionForBufferRange range
    else
      @miniEditor.getModel().setTextInBufferRange range, ""

  # Try to complete the text from @bangCommands.matchList
  complete: ->
    word = @miniEditor.getText()
    return if (option = @bangCommands.completeCMD word) is null
    @miniEditor.getModel().setText option

  # Retrieves the reference directory for the relative paths
  referenceDir: ->
    homeDir = process.env.HOME or process.env.HOMEPATH or process.env.USERPROFILE
    atom.project.getPaths()[0] or homeDir

  storeFocusedElement: ->
    @previouslyFocusedElement = $(':focus')

  restoreFocus: ->
    if @previouslyFocusedElement?.isOnDom()
      @previouslyFocusedElement.focus()
    else
      atom.views.getView(atom.workspace).focus()
