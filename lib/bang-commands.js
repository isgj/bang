'use babel'

export default class BangCommands {

  constructor (data) {
    // The list of all executed commands
    this.cmdList = data || []
    // The list of commands that start with the text we have inserted (this.query)
    this.matchList = []
    // The last index in this.matchList we suggested
    this.next = -1
    // The last query we have used to update the this.matchList
    this.query = null
  }

  getNextCMD (word, i) {
    this.updateMatchList(word)

    if (this.matchList.length) {
      this.next += i
      if (i === 1 && this.next > this.matchList.length) {
        this.next = 0
      } else if (i === -1 && this.next < -1) {
        this.next = this.matchList.length -1
      }

      if (this.next >= 0 && this.next < this.matchList.length) {
        return this.matchList[this.next].slice(word.length)
      }
    }
    return null
  }

  completeCMD (word) {
    if (!word) return null

    this.updateMatchList(word)

    if (!this.matchList.length) return null
    if (this.matchList.length === 1) return this.matchList[0]

    for (let charPos = word.length; this.commonInPoss(charPos); charPos++) {
      word += this.matchList[0][charPos]
    }

    return word
  }

  commonInPoss (pos) {
    const char = this.matchList[0][pos]
    for (let cmd of this.matchList) {
      if (cmd[pos] !== char) return false
    }
    return true
  }

  updateMatchList (word) {
    if (this.query === word) return

    const fromQuery = this.query && word.slice(0, this.query.length) === this.query
    const listToSearch = fromQuery ? this.matchList : this.cmdList

    this.query = word
    if (listToSearch.length) {
      this.matchList = listToSearch.filter( entry => {
        return entry.length > this.query.length && entry.startsWith(this.query)
      })
    } else {
      this.matchList = []
    }

    this.next = -1
  }

  addCommand (cmd) {
    this.query = null
    this.cmdList = [cmd].concat(this.cmdList.filter(c => c !== cmd))
    return this.cmdList
  }

  serialize () {
    const toSave = atom.config.get('bang.numberOfCommandsToSave')
    if (this.cmdList.length > toSave) {
      this.cmdList = this.cmdList.slice(0, toSave)
    }
    return {deserializer: 'BangCommands', data: this.cmdList}
  }

}
