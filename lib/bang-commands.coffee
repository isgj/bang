module.exports =
class BangCommands
  constructor: (data) ->
    @list = data
    @next = 0
    @oldList = null
    @oldWord = null

  getNextCMD: (word, i) ->
    if @oldWord is word
      if i is 'n'
        @next++
      else
        @next--
        if @next is -1
          @next += @oldList.length
      if @oldList.length
        n = @next % @oldList.length
        return @oldList[n][word.length...] if @oldList[n] isnt null
      return ""
    else
      if @oldWord?.length and word[...@oldWord.length] is @oldWord
        @oldWord = word
        @updateList @oldList
      else
        @oldWord = word
        @updateList @list
    @getNextCMD @oldWord, i

  updateList: (filterList) ->
    len = @oldWord.length
    if filterList isnt null
      list = (word for word in filterList when word isnt null and word.startsWith @oldWord)
    else
      list = []
    @oldList = list
    @oldList.unshift null
    @next = 0

  addCommand: (cmd) ->
    @oldWord = null
    newlist = (oldCmd for oldCmd in @list when oldCmd isnt cmd)
    @list = newlist
    @list.unshift cmd

  atom.deserializers.add(this)

  @deserialize: ({data}) -> new BangCommands(data)

  serialize: -> {deserializer: 'BangCommands', data: @list}
