{Range, CompositeDisposable} = require 'atom'
_ = require 'underscore-plus'
HighlightedStatusView = require './highlighted-status-view'

module.exports =
class HighlightedAreaView

  constructor: ->
    @views = []
    @listenForTimeoutChange()
    @activeItemSubscription = atom.workspace.onDidChangeActivePaneItem =>
      @debouncedHandleSelection()
      @subscribeToActiveTextEditor()
    @subscribeToActiveTextEditor()

  setStatusBar: (statusBar) ->
    @statusBar = statusBar

  destroy: =>
    clearTimeout(@handleSelectionTimeout)
    @activeItemSubscription.dispose()
    @selectionSubscription?.dispose()

  debouncedHandleSelection: =>
    clearTimeout(@handleSelectionTimeout)
    @handleSelectionTimeout = setTimeout =>
      @handleSelection()
    , atom.config.get('selection-highlight.timeout')

  listenForTimeoutChange: ->
    atom.config.onDidChange 'selection-highlight.timeout', =>
      @debouncedHandleSelection()

  subscribeToActiveTextEditor: ->
    @selectionSubscription?.dispose()

    editor = @getActiveEditor()
    return unless editor

    @selectionSubscription = new CompositeDisposable

    @selectionSubscription.add(
      editor.onDidAddSelection @debouncedHandleSelection
    )
    @selectionSubscription.add(
      editor.onDidChangeSelectionRange @debouncedHandleSelection
    )
    @handleSelection()

  getActiveEditor: ->
    atom.workspace.getActiveTextEditor()

  handleSelection: =>
    @removeMarkers()

    editor = @getActiveEditor()
    return unless editor
    return if editor.getLastSelection().isEmpty()
    return unless @isWordSelected(editor.getLastSelection())

    @selections = editor.getSelections()

    text = _.escapeRegExp(@selections[0].getText())
    regex = new RegExp("\\S*\\w*\\b", 'gi')
    if atom.config.get('selection-highlight.searchAnyCharacter')
      regex = new RegExp("[\\s\\S]*", 'gi')
    result = regex.exec(text)

    return unless result?
    return if result[0].length < atom.config.get(
      'selection-highlight.minimumLength') or
              result.index isnt 0 or
              result[0] isnt result.input

    regexFlags = 'g'
    if atom.config.get('selection-highlight.ignoreCase')
      regexFlags = 'gi'

    range =  [[0, 0], editor.getEofBufferPosition()]

    @ranges = []
    regexSearch = result[0]

    if atom.config.get('selection-highlight.onlyHighlightWholeWords')
      if regexSearch.indexOf("\$") isnt -1 \
      and editor.getGrammar()?.name is 'PHP'
        regexSearch = regexSearch.replace("\$", "\$\\b")
      else
        regexSearch =  "\\b" + regexSearch
      regexSearch = regexSearch + "\\b"

    limit = atom.config.get('selection-highlight.highlightStop')
    count = 0

    editor.scanInBufferRange new RegExp(regexSearch, regexFlags), range,
      (result) =>
        count = count + 1
        unless @showHighlightOnSelectedWord(result.range, @selections) or limit <= 0
          limit = limit - 1
          marker = editor.markBufferRange(result.range)
          decoration = editor.decorateMarker(marker,
            {type: 'highlight', class: @makeClasses()})
          @views.push marker

    if atom.config.get('selection-highlight.highlightInOtherPanes')
      for pane in atom.workspace.getPanes()
        item = pane.getActiveItem()
        if (item?) and (item.constructor.name is editor.constructor.name) and not (item is editor)
          range = [[0, 0], item.getEofBufferPosition()]
          item.scanInBufferRange new RegExp(regexSearch, regexFlags), range,
            (result) =>
              count = count + 1
              unless limit <= 0
                limit = limit - 1
                marker = item.markBufferRange(result.range)
                decoration = item.decorateMarker(marker,
                  {type: 'highlight', class: @makeClasses()})
                @views.push marker
      
      
      


    @statusNumber = new HighlightedStatusView()
    @statusNumber.initialize(@statusBar)
    @statusNumber.setCount(count)
    @statusNumber.attach()

  makeClasses: ->
    className = 'highlight-selected'
    if atom.config.get('selection-highlight.lightTheme')
      className += ' light-theme'

    if atom.config.get('selection-highlight.highlightBackground')
      className += ' background'
    className

  showHighlightOnSelectedWord: (range, selections) ->
    return false unless atom.config.get(
      'selection-highlight.hideHighlightOnSelectedWord')
    outcome = false
    for selection in selections
      selectionRange = selection.getBufferRange()
      outcome = (range.start.column is selectionRange.start.column) and
                (range.start.row is selectionRange.start.row) and
                (range.end.column is selectionRange.end.column) and
                (range.end.row is selectionRange.end.row)
      break if outcome
    outcome

  removeMarkers: =>
    if @statusNumber
      @statusNumber.destroy()
    return unless @views?
    return if @views.length is 0
    for view in @views
      view.destroy()
      view = null
    @views = []

  isWordSelected: (selection) ->
    if atom.config.get('selection-highlight.searchOnPartialWords')
      true
    else if selection.getBufferRange().isSingleLine()
      selectionRange = selection.getBufferRange()
      lineRange = @getActiveEditor().bufferRangeForBufferRow(
        selectionRange.start.row)
      nonWordCharacterToTheLeft =
        _.isEqual(selectionRange.start, lineRange.start) or
        @isNonWordCharacterToTheLeft(selection)
      nonWordCharacterToTheRight =
        _.isEqual(selectionRange.end, lineRange.end) or
        @isNonWordCharacterToTheRight(selection)

      nonWordCharacterToTheLeft and nonWordCharacterToTheRight
    else
      false

  isNonWordCharacter: (character) ->
    nonWordCharacters = atom.config.get('editor.nonWordCharacters')
    new RegExp("[ \t#{_.escapeRegExp(nonWordCharacters)}]").test(character)

  isNonWordCharacterToTheLeft: (selection) ->
    selectionStart = selection.getBufferRange().start
    range = Range.fromPointWithDelta(selectionStart, 0, -1)
    @isNonWordCharacter(@getActiveEditor().getTextInBufferRange(range))

  isNonWordCharacterToTheRight: (selection) ->
    selectionEnd = selection.getBufferRange().end
    range = Range.fromPointWithDelta(selectionEnd, 0, 1)
    @isNonWordCharacter(@getActiveEditor().getTextInBufferRange(range))
