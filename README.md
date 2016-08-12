# Bang package

Run a shell command to filter the text or show the output
## How to use
---
#### Bang : Edit text
 + command
 	- Bang: Edit Text
 + shortcut
  	- ctrl-alt-e

This function will:
 1. run the command you enter
   	+ give as input to the command the selected text if there is one
 2. insert the output of the command in the editor
 	+ or replace the selected text if there is one

![Bang: Edit Text](/img/edittext.gif "Bang: Edit text")

------
#### Bang : Run a command
+ command
   - Bang: Run A Command
+ shortcut
   - ctrl-alt-c

This function will:
1. run the command you enter
   + give as input to the command the selected text if there is one
2. show a notification with the output of your command

![Bang: Run A Command](/img/runacmd.gif "Bang: Run A Command")

---
The base code of this package was (and is) [Go to line package](https://github.com/atom/go-to-line)
