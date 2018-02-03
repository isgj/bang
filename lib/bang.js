'use babel'

import { TextEditor, CompositeDisposable } from 'atom'
import { execSync, exec } from 'child_process'
import BangCommands from './bang-commands'

class BangView {
  constructor (state) {
    // Create the view
    this.miniEditor = new TextEditor({ mini: true })
    this.miniEditor.element.addEventListener('blur', this.close.bind(this))

    this.message = document.createElement('div')
    this.message.classList.add('message')

    this.element = document.createElement('div')
    this.element.classList.add('bang')
    this.element.appendChild(this.miniEditor.element)
    this.element.appendChild(this.message)

    this.panel = atom.workspace.addModalPanel({
      item: this,
      visible: false
    })

    // Restore previuos state
    this.bangCommands =
      state.bangCommandsState !== undefined ?
      atom.deserializers.deserialize(state.bangCommandsState) :
      new BangCommands([])

    // Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    this.subscriptions = new CompositeDisposable()

    // Register commands that toggles this view
    this.subscriptions.add(atom.commands.add('atom-text-editor', {
      'bang:edit-text': () => {
        this.dryCmd = false
        this.outFn = this.editText
        this.toggle()
        return false
      }
    }))
    this.subscriptions.add(atom.commands.add('atom-workspace', {
      'bang:run-a-command': () => {
        this.dryCmd = true
        this.outFn = this.bangNotification
        this.toggle()
        return false
      }
    }))
    this.subscriptions.add(atom.commands.add('atom-workspace', {
      'bang:result-in-new-document': () => {
        this.dryCmd = true
        this.outFn = this.bangDocument
        this.toggle()
        return false
      }
    }))

    // Register commands to interact with the package
    this.subscriptions.add(atom.commands.add(this.miniEditor.element, {'bang:confirm': () => this.confirm()}))
    this.subscriptions.add(atom.commands.add(this.miniEditor.element, {'bang:cancel': () => this.close()}))
    this.subscriptions.add(atom.commands.add(this.miniEditor.element, {'bang:next': () => this.next(1)}))
    this.subscriptions.add(atom.commands.add(this.miniEditor.element, {'bang:prev': () => this.next(-1)}))
    this.subscriptions.add(atom.commands.add(this.miniEditor.element, {'bang:complete': () => this.complete()}))
  }

  // Toggle this view
  toggle () {
    this.panel.isVisible() ? this.close() : this.open()
  }

  // Show the panel and get focus
  open () {
    if (this.panel.isVisible()) return
    const editor = atom.workspace.getActiveTextEditor()
    this.storeFocusedElement()
    this.panel.show()
    this.message.textContent =
      this.dryCmd ?
        'Bang a command' :
        editor.getSelectedText().length ?
          'Filter the selected text with your command' :
          'Insert the output of the command in the text buffer'

    this.miniEditor.element.focus()
  }

  editText ({editor, message}) {
    const range = editor.getSelectedBufferRange()
    editor.setTextInBufferRange(range, message)
  }

  bangNotification ({title, message, dismiss}) {
    atom.notifications.addSuccess(title, {detail: message, dismissable: dismiss})
  }

  bangDocument ({message}) {
    atom.workspace.open().then(textEditor => {
      textEditor.setText(message)
    })
  }

  // Running the command
  confirm () {
    const cmd = this.miniEditor.getText().trim()
    this.bangCommands.addCommand(cmd)
    const editor = atom.workspace.getActiveTextEditor()
    this.close()

    // The edit-text needs an active text editor
    if (!this.dryCmd && !editor) {
      return
    }

    let cwd
    if (editor.getPath()) {
      // We set the current working directory like this
      // only if the file is saved in the disk
      const cwdLength = editor.getPath().length - editor.getTitle().length
      cwd = editor.getPath().slice(0, cwdLength)
    } else {
      // A file has no name :)
      // it's a new buffer
      cwd = this.referenceDir()
    }

    // The text to give as input to the command
    const input = editor ? editor.getSelectedText() : ''

    let dirMessage = cwd + ':$ ' + cmd

    // Get the configurations
    const missNote = atom.config.get('bang.doNotAutoHideNotifications')
    const shellConfig = atom.config.get('bang.shell')
    const pathConfig = atom.config.get('bang.path')

    // Run an asynchronous process if there
    // is no input and don't have to edit the text
    if (this.dryCmd && input.length === 0) {
      exec(cmd, {cwd: cwd, env: {PATH: pathConfig}, shell: shellConfig}, (error, stdout, stderr) => {
        if (error) {
          dirMessage += '\n' + stderr
          atom.notifications.addWarning('Attention', {detail: dirMessage, dismissable: missNote})
          return
        }
        this.outFn({title: dirMessage, message: stdout, dismiss: missNote})
      })
      return
    }

    try {
      const output = execSync(cmd, {cwd: cwd, input: input, env: {PATH: pathConfig}, shell: shellConfig, timeout: 5e3})
      const outMessage = output.toString()
      if (outMessage.length) {
        this.outFn({editor: editor, title: dirMessage, message: outMessage, dismiss: missNote})
      }
    } catch (e) {
      dirMessage += '\n' + e.stderr.toString()
      atom.notifications.addWarning('Attention', {detail: dirMessage, dismissable: missNote})
    }
  }

  // Close the view
  close () {
    if (!this.panel.isVisible()) return
    this.miniEditor.setText('')
    this.panel.hide()
    this.bangCommands.next = 0
    if (this.miniEditor.element.hasFocus()) {
      this.restoreFocus()
    }
  }

  // Get a suggestion from this.bangCommands.matchList
  // UP arrow =>
  //    input: 1
  //    output: cycle from the most recent to the most previously command direction
  // DOWN arrow =>
  //    input: -1
  //    output: cycle form the most previously to the most recent command direction
  next (direction) {
    let range = this.miniEditor.getSelectedBufferRange()
    this.miniEditor.setTextInBufferRange(range, '')
    const word = this.miniEditor.getText().trim()
    const suggestion = this.bangCommands.getNextCMD(word, direction)
    if (suggestion) {
      range = this.miniEditor.setTextInBufferRange(range, suggestion)
      this.miniEditor.addSelectionForBufferRange(range)
    }
  }

  // Try to complete the text from this.bangCommands.matchList
  complete () {
    const word = this.miniEditor.getText()
    const suggested = this.bangCommands.completeCMD(word)
    if (suggested) {
      this.miniEditor.setText(suggested)
    }
  }

  storeFocusedElement () {
    this.previouslyFocusedElement = document.activeElement
  }

  restoreFocus () {
    if (this.previouslyFocusedElement && this.previouslyFocusedElement.parentElement) {
      return this.previouslyFocusedElement.focus()
    }
    atom.views.getView(atom.workspace).focus()
  }

  referenceDir () {
    const dir = atom.project.getPaths()[0]
    // dir should not be empty but just in case
    return dir || process.env.HOME || process.env.HOMEPATH || process.env.USERPROFILE
  }
}

export default {
  // Activate the package
  activate (state) {
    this.package = new BangView(state)
    return this.package
  },
  // Deactivate the package
  deactivate () {
    this.package.panel.destroy()
    this.package.subscriptions.dispose()
    this.package.miniEditor.destroy()
  },
  // Serialize the list of commands
  serialize () {
    return {
      bangCommandsState: this.package.bangCommands.serialize()
    }
  },
  // Deserialize the list of saved commands
  deserialize ({data}) {
    return new BangCommands(data)
  },
  // configurations
  config: {
    numberOfCommandsToSave: {
      type: 'integer',
      default: 100,
      minimum: 1,
      maximum: 1000
    },
    doNotAutoHideNotifications: {
      type: 'boolean',
      default: true
    },
    shell: {
      type: 'string',
      default: process.env.SHELL
    },
    path: {
      type: 'string',
      default: process.env.PATH
    }
  }
}
