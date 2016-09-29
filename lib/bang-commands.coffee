module.exports =
class BangCommands
  constructor: (data) ->
    # The list of all executed commands
    @cmdList = data

    # The list of commands that start with the
    # text we have inserted (@query)
    @matchList = null

    # The last index in @matchList we suggested
    @next = 0

    # The last query we have used to update the @matchList
    @query = null

  getNextCMD: (word, i) ->
    @updateMatchList word
    if i is 'n'
      @next++
    else
      @next--
      if @next is -1
        @next += @matchList.length
    if @matchList.length
      n = @next % @matchList.length
      return @matchList[n][word.length...] if @matchList[n]?
    return null

  completeCMD: (word) ->
    return null if word?.length is 0
    @updateMatchList word
    return null if @matchList is null or @matchList.length is 1
    return @matchList[1] if @matchList.length is 2
    len = word.length
    while @commonInPoss len
      word += @matchList[1][len]
      len++
    return word

  commonInPoss: (pos) ->
    char = @matchList[1][pos]
    for word in @matchList
      if word is null
        continue
      if word[pos] isnt char
        return false
    return true

  updateMatchList: (word) ->
    return if @query is word
    len = @query?.length
    if word[...len] is @query
      @query = word
      if @matchList?
        @matchList = (cmdEntry for cmdEntry in @matchList when @isIndexOf @query, cmdEntry)
      else
        @matchList = []
    else
      @query = word
      if @cmdList isnt null
        @matchList = (cmdEntry for cmdEntry in @cmdList when @isIndexOf @query, cmdEntry)
      else
        @matchList = []
    @matchList.unshift null
    @next = 0

  isIndexOf: (index, entry) ->
    return entry? and entry.length > index.length and entry.startsWith index

  addCommand: (cmd) ->
    @query = null
    newlist = (oldCmd for oldCmd in @cmdList? when oldCmd isnt cmd)
    @cmdList = newlist
    @cmdList.unshift cmd

  atom.deserializers.add(this)

  @deserialize: ({data}) -> new BangCommands(data)

  serialize: ->
    n = atom.config.get 'bang.numberOfCommandsToSave'
    if @cmdList?.length > n
      @cmdList = @cmdList[...n]
    {deserializer: 'BangCommands', data: @cmdList}
