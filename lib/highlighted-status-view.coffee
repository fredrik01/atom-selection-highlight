module.exports =
class HighlightedStatusView extends HTMLDivElement

  initialize: (@statusBar) ->
    @count = 0
    @element = document.createElement 'div'
    @classList.add('hl-selected', 'inline-block')
    @appendChild(@element)

  setCount: (@count) ->
    @element.textContent = 'Found: ' + @count

  attach: ->
    @tile = @statusBar.addLeftTile(priority: 100, item: this)

  detach: ->
    bar = document.getElementsByTagName 'highlighted-status-bar'
    if bar != null
      if bar.item() != null
        el = bar[0]
        parent = el.parentNode
        if parent != null
          parent.removeChild el

  destroy: ->
    @tile?.destroy()
    @detach()

module.exports = document.registerElement('highlighted-status-bar',
  prototype: HighlightedStatusView.prototype)
