{$, View, TextEditorView}  = require('atom-space-pen-views')
{CompositeDisposable} = require 'atom'
execSync = require('child_process').execSync
exec = require('child_process').exec
BangCommands = require './bang-commands'
BangView = require './bang-view'

module.exports = Bang =
  bangView: null
  bangCommands: null
  modalPanel: null
  subscriptions: null
  ## The variable to check in which mode the view is running
  ## false: the output of the command will edit the text
  ## true: the output will be shown in a notification
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
    @miniEditor.on 'blur', => @close()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @bangView.destroy()

  serialize: ->
    bangCommandsState: @bangCommands.serialize()

  toggle: ->
    if @modalPanel.isVisible()
      @close()
    else
      @open()

  close: ->
    return unless @modalPanel.isVisible()
    miniEditorFocused = @miniEditor.hasFocus()
    @miniEditor.getModel().setText('')
    @modalPanel.hide()
    @restoreFocus() if miniEditorFocused

  confirm: ->
    cmd = @miniEditor.getText().trim()
    @bangCommands.addCommand cmd
    editor = atom.workspace.getActiveTextEditor()
    @close()
    ## The edit-text needs an active text editor
    if not @dryCmd
      return unless editor?
    if editor.getPath()
      ## We set the current working directory like this
      ## only if the file is saved in the disk
      cwdLength = editor.getPath().length - editor.getTitle().length
      cwd = editor.getPath()[0...cwdLength]
    else
      ## A file has no name :)
      ## it's a new buffer
      cwd = @referenceDir()
    ## The text to give as input to the command
    input = editor?.getSelectedText()
    dirMessage = cwd + ':$ ' + cmd
    if @dryCmd and not input.length
      exec cmd, cwd: cwd, (error, stdout, stderr) =>
        if error
          dirMessage += '\n' + stderr
          atom.notifications.addWarning('Attention', {detail: dirMessage})
          @dryCmd = false
          return
        msgTitle = cwd + ':$ ' + cmd
        atom.notifications.addSuccess(msgTitle, {detail: stdout, dismissable: true})
        @dryCmd = false
        return
      return
    try
      output = execSync cmd, {cwd, input: input, timeout: 5e3}
      output = output.toString()
    catch e
      dirMessage += '\n' + e.stderr.toString()
      atom.notifications.addWarning('Attention', {detail: dirMessage})
      @dryCmd = false
      return
    if output.length
      ## Check where to put the output of cmd
      if @dryCmd
        atom.notifications.addSuccess(dirMessage, {detail: output, dismissable: true})
        @dryCmd = false
      else
        range = editor.getSelectedBufferRange()
        editor.setTextInBufferRange range, output

  open: ->
    return if @modalPanel.isVisible()
    if editor = atom.workspace.getActiveTextEditor()
      @storeFocusedElement()
      @modalPanel.show()
      if editor.getSelectedText()?.length
        @bangView.setMessage("Filter the selected text with your command")
      else
        @bangView.setMessage("Bang a command")
        @miniEditor.focus()

  next: (i) ->
    console.log @bangCommands.getNextCMD(@miniEditor.getText().trim(), i)

  ## Retrieves the reference directory for the relative paths
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
