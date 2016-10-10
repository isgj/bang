# Bang package

Run a shell command to filter the text or show the output in [Atom Text Editor](https://atom.io).

![bang.gif](https://raw.githubusercontent.com/isgj/bang/31ceef28136651933ad7198741ad88bb26686cc6/img/bang.gif)

## How to use

| Command | Key Binding | What it does
|---------|-------------|------------
|**Bang: Edit Text**|`ctrl-alt-e`| When confirmed this function will run the command and give as input the selected text if there is one. After will insert the output in the editor or replace the selected text. To run this function the cursor has to be in the editor.
|**Bang : Run a command**|`ctrl-alt-c`| When confirmed this function will run the command like `Bang: Edit Text` but the output is shown in a notification. If there is no input it runs asynchronously.
|**Confirm**|**`ENTER`**| When writing the command will confirm `Bang: Edit Text` or `Bang: Run a command`
|**Next** or **Previous**|`UP arrow` :arrow_up: or `Down arrow` :arrow_down:| Will cycle through the history of the commands you have entered (`next: more recent`, `previous: less recent`)
|**Complete**|**`TAB`**| Will try to complete your command
|**Cancel**|**`ECS`** or `ctrl-w`| Will cancel the view without running the command

> The commands will run in the same directory of the file that is shown in the editor

> If the file is not saved (untitled) the command will run in the Project directory

## Custom Keybinding

See [Keymaps In-Depth](http://flight-manual.atom.io/behind-atom/sections/keymaps-in-depth/) for more details.

For example:

```coffeescript
'atom-workspace':
	'ctrl-alt-e': 'bang:edit-text'
	'ctrl-alt-c': 'bang:run-a-command'
```
> Use `atom-workspace` as selector.

---
The base code of this package was (and is) [Go to line package](https://github.com/atom/go-to-line)

This package is inspired by ***bang*** function of [Vim](http://www.vim.org/)
