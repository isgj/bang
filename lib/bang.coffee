{$, TextEditorView, View}  = require 'atom-space-pen-views'
execSync = require('child_process').execSync
exec = require('child_process').exec

module.exports =
    class BangView extends View
        @activate: -> new BangView

        @content: ->
            ## Attributes for the text editor to create
            cmdBuffer =
                mini: true
                placeholderText: 'Eneter your command here'

            @div class: 'bang', =>
                @subview 'miniEditor', new TextEditorView(cmdBuffer)
                @div class: 'message', outlet: 'message'

        initialize: ->
            @panel = atom.workspace.addModalPanel(item: this, visible: false)
            ## The variable to check in which mode the view is running
            ## false: the output of the command will edit the text
            ## true: the output will be shown in a notification
            @dryCmd = false
            ## Register commands that toggle this view
            atom.commands.add 'atom-text-editor', 'bang:edit-text', => @toggle()
            atom.commands.add 'atom-workspace', 'bang:run-a-command', => @drytoggle()

            @miniEditor.on 'blur', => @close()
            atom.commands.add @miniEditor.element, 'bang:confirm', => @confirm()
            atom.commands.add @miniEditor.element, 'bang:cancel', => @close()

        toggle: ->
            if @panel.isVisible()
                @close()
            else
                @open()

        drytoggle: ->
            @dryCmd = true
            @toggle()

        close: ->
            return unless @panel.isVisible()
            miniEditorFocused = @miniEditor.hasFocus()
            @miniEditor.setText('')
            @panel.hide()
            @restoreFocus() if miniEditorFocused

        confirm: ->
            cmd = @miniEditor.getText().trim()
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
            return if @panel.isVisible()
            if editor = atom.workspace.getActiveTextEditor()
                @storeFocusedElement()
                @panel.show()
                if editor.getSelectedText()?.length
                    @message.text("Filter the selected text with your command")
                else
                    @message.text("Bang a command")
                @miniEditor.focus()

        ## Retrieves the reference directory for the relative paths
        referenceDir: () ->
            homeDir = process.env.HOME or process.env.HOMEPATH or process.env.USERPROFILE
            atom.project.getPaths()[0] or homeDir

        storeFocusedElement: ->
            @previouslyFocusedElement = $(':focus')

        restoreFocus: ->
            if @previouslyFocusedElement?.isOnDom()
                @previouslyFocusedElement.focus()
            else
                atom.views.getView(atom.workspace).focus()
