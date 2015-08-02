HighlightedAreaView = require './highlighted-area-view'

areaView: null
statusView = null
statusTile = null

module.exports =
  config:
    onlyHighlightWholeWords:
      type: 'boolean'
      default: false
    hideHighlightOnSelectedWord:
      type: 'boolean'
      default: false
    ignoreCase:
      type: 'boolean'
      default: false
    lightTheme:
      type: 'boolean'
      default: false
    highlightBackground:
      type: 'boolean'
      default: false
    minimumLength:
      type: 'integer'
      default: 0
    timeout:
      type: 'integer'
      default: 20
      description: 'Defers searching for matching strings for X ms'

  activate: (@state)

  consumeStatusBar: (statusBar) ->
    @areaView = new HighlightedAreaView()
    @areaView.setStatusBar statusBar

  deactivate: ->
    @areaView?.destroy()
    @areaView = null
