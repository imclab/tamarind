browserSupportsRequiredFeaturesCache = null

_tamarindGlobal = null

module.exports =



  ###
    Define a property on a class.

    If the property is `"fooBar"` then this method will require one or both of
    `_getFooBar()` or `_setFooBar(value)` to exist on the class and create a
    read-write, read-only or write-only property as appropriate.

    Additionally, a default value for the property can be provided in the class
    definition alongside the method declarations.

    @example
      class Foo
        prop: 4 # default value, will be set as prototype._prop = 4
        _getProp: -> @_prop
        _setProp: (val) -> @_prop = val

      defineClassProperty Foo, "prop"
  ###
  defineClassProperty: (cls, propertyName) ->
    PropertyName = propertyName[0].toUpperCase() + propertyName.slice(1)
    getter = cls.prototype['_get' + PropertyName]
    setter = cls.prototype['_set' + PropertyName]

    unless getter or setter
      throw new Error(propertyName + ' must name a getter or a setter')

    initialValue = cls.prototype[propertyName]
    unless initialValue is undefined
      cls.prototype['_' + propertyName] = initialValue

    config =
      enumerable: true
      get: getter or -> throw new Error(propertyName + ' is write-only')
      set: setter or -> throw new Error(propertyName + ' is read-only')

    Object.defineProperty cls.prototype, propertyName, config

    return


  ###
    Return false if the browser can't handle the awesome.
  ###
  browserSupportsRequiredFeatures: ->
    if browserSupportsRequiredFeaturesCache is null

      try
        canvas = document.createElement 'canvas'
        ctx = canvas.getContext('webgl') or canvas.getContext('experimental-webgl')

      browserSupportsRequiredFeaturesCache = !!(ctx and Object.defineProperty)

    return browserSupportsRequiredFeaturesCache



  ###
    Convert an HTML string representing a single element into a DOM node.
  ###
  parseHTML: (html) ->
    tmp = document.createElement 'div'
    tmp.innerHTML = html.trim()
    if tmp.childNodes.length > 1
      throw new Error 'html must represent single element'
    el = tmp.childNodes[0]
    tmp.removeChild el
    return el


  # Record an error. This will results in a thrown exception in debugMode or a console error in normal mode
  logError: (message) ->
    if _tamarindGlobal?.debugMode
      throw new Error('debugMode: ' + message)
    else
      console.error message
    return


  # Record an event. This will results in a console log in debugMode or nothing in normal mode
  logInfo: (message) ->
    if _tamarindGlobal?.debugMode
      console.log message
    return

  # used to wire up the Tamarind class without creating a circular dependency by require'ing it at the top of the file
  setTamarindGlobal: (tg) ->
    _tamarindGlobal = tg
    return


  # check whether a value is the correct type
  # @param expectedType either a string, in which case it must equal `typeof actualValue`, or
  #                     a function, in which case `actualValue instanceof expectedType` must be true
  validateType: (actualValue, expectedType, propertyName) ->
    if typeof expectedType is 'string'
      correct = typeof actualValue is expectedType
    else if typeof expectedType is 'function'
      correct = actualValue instanceof expectedType
    else
      throw new Error("expectedType must be a string or class, not '#{expectedType}'")

    unless correct
      throw new Error("Can't set '#{propertyName}' to '#{actualValue}': expected a '#{expectedType}'")