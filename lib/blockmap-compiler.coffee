openKeywords = /begin|case|class|def|do|for|module|unless|while/
ifKeyword = /if/
intermediateKeywords = /break|else|elsif|ensure|next|rescue|return/
endKeyword = /end/

class Parameters
  constructor: (@keyword, @lineNumber, @position, @length) ->

class BlockMap
  constructor: ->
    @map = []

  entryAt: (lineNumber) ->
    @map[lineNumber] ||= []

  putEntry: (parameters, block) ->
    @entryAt(parameters.lineNumber)[parameters.position] =
      {block, parameters, appendants: block.getAppendants(parameters.lineNumber)}

  push: (block) ->
    @putEntry(block.begin, block)
    for intermediate in block.intermediates
      @putEntry(intermediate, block)
    @putEntry(block.end, block)

class Block
  constructor: (@begin) ->
    @intermediates = []

  pushInbetween: (parameters) ->
    @intermediates.push(parameters)

  pushEnd: (parameters) ->
    @end = parameters

  makeAppendant: (parameters, lineNumberToExclude) ->
    unless lineNumberToExclude is parameters.lineNumber
      [parameters.lineNumber, parameters.position]

  getAppendants: (lineNumberToExclude) ->
    appendants = []
    for candiate in [@begin, @end].concat(@intermediates)
      appendants.push(a) if a = @makeAppendant(candiate, lineNumberToExclude)
    return appendants

class Stack
  constructor: (@blockMap) ->
    invisiblesSpace = atom.config.get('editor.invisibles.space')
    @invisiblesRegex = new RegExp("^#{invisiblesSpace}*if")
    @stack = []

  push: (parameters, line) ->
    # TODO
    # this handles the intermediates first, because of the if that also appears
    # in elsif. maybe this should be taken care of with a more specific regex.
    if intermediateKeywords.test(parameters.keyword)
      @getTop()?.pushInbetween(parameters)

    else if ifKeyword.test(parameters.keyword)
      if @invisiblesRegex.test(line.text)
        @stack.push(new Block(parameters))

    else if openKeywords.test(parameters.keyword)
      @stack.push(new Block(parameters))

    else if endKeyword.test(parameters.keyword)
      @getTop()?.pushEnd(parameters)
      block = @stack.pop()
      @blockMap.push(block) if block

  getTop: ->
    @stack[@stack.length-1]

getPositionAndLength = (tags, index) ->
  counter = 0
  position = 0
  while counter < index
    position += tags[counter]
    counter++
  return [position, tags[counter]]

module.exports = (lines) ->
  blockMap = new BlockMap()
  stack = new Stack(blockMap)
  for line, lineNumber in lines
    tags = line.tags.filter (n) -> n >= 0
    for token, index in line.tokens
      for scope in token.scopes
        if scope.indexOf("keyword") >= 0
          [position, length] = getPositionAndLength(tags, index)
          stack.push(new Parameters(token.value, lineNumber, position, length), line)

  return blockMap.map
