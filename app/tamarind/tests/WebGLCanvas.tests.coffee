WebGLCanvas         = require '../WebGLCanvas.coffee'
State               = require '../State.coffee'
constants           = require '../constants.coffee'
ShaderCompileError  = require '../ShaderCompileError.coffee'
datauri             = require 'datauri'


VSHADER_HEADER = '''
attribute float a_VertexIndex;
varying vec2 v_position;
'''

VSHADER_REFERENCE = VSHADER_HEADER + '''

void main() {
  if (a_VertexIndex == 0.0) {
    v_position = vec2(-1, -1);
  } else if (a_VertexIndex == 1.0) {
    v_position = vec2(1, -1);
  } else if (a_VertexIndex == 2.0) {
    v_position = vec2(1, 1);
  } else if (a_VertexIndex == 3.0) {
    v_position = vec2(-1, 1);
  } else {
    v_position = vec2(0);
  }
  gl_Position.xy = v_position;
}
'''

FSHADER_HEADER = '''
precision mediump float;
varying vec2 v_position;
'''

FSHADER_REFERENCE = FSHADER_HEADER + '''
void main() {
  gl_FragColor = vec4(v_position * 0.5 + 0.5, 1, 1);
}
'''

referenceImageUri = datauri(__dirname + '/reference-images/plain-shader.png')


compareAgainstReferenceImage = (webglCanvas, referenceImageUrl, done) ->

  imageToDataUrl = (imageElement) ->
    canvasElement = document.createElement 'canvas'
    canvasElement.width = imageElement.width
    canvasElement.height = imageElement.height
    ctx = canvasElement.getContext '2d'
    ctx.drawImage(imageElement, 0, 0)
    return canvasElement.toDataURL('image/png')

  loaded = 0

  handleLoad = ->
    ++loaded
    if loaded is 2
      expectedData = imageToDataUrl(expected)
      actualData = imageToDataUrl(actual)
      unless expectedData is actualData
        window.focus()
        console.log 'EXPECTED DATA: ' + expectedData
        console.log 'ACTUAL DATA: ' + actualData
        unless document.location.href.indexOf('bad-images') is -1
          window.open expectedData
          window.open actualData
        else
          console.log 'PRO TIP: append ?bad-images to the Karma runner URL and reload to view these images'
        expect(false).toBeTruthy()
      done()
    return

  actual = new Image()
  actual.onload = handleLoad
  actual.src = webglCanvas.captureImage(100, 100)

  expected = new Image()
  expected.onload = handleLoad
  expected.onerror = -> throw new Error("Couldn't load " + referenceImageUrl)
  expected.src = referenceImageUrl

  return


describe 'WebGLCanvas', ->

  createCanvasAndState = ->
    state = new State()
    canvas = new WebGLCanvas(state)
    return [canvas, state]

  it 'should render a test image', (done) ->

    [canvas, state] = createCanvasAndState()

    state.setShaderSource constants.VERTEX_SHADER, VSHADER_REFERENCE
    state.setShaderSource constants.FRAGMENT_SHADER, FSHADER_REFERENCE

    compareAgainstReferenceImage canvas, referenceImageUri, done

    return

  it 'should handle the loss and restoration of the webgl context gracefully', (done) ->

    [canvas, state] = createCanvasAndState()

    # browsers don't like losing and restoring the context on the same frame, so we do this as a series of 4 frames

    frames = [
      ->
        canvas.debugLoseContext()
        return
      ->
        # set some state while the context is lost
        state.setShaderSource constants.VERTEX_SHADER, VSHADER_REFERENCE
        state.setShaderSource constants.FRAGMENT_SHADER, FSHADER_REFERENCE
        return
      ->
        canvas.debugRestoreContext()
        return
      ->
        compareAgainstReferenceImage canvas, referenceImageUri, done
        return
    ]

    frame = 0
    doNextFrame = ->
      frames[frame]()
      frame++
      if frames[frame]
        requestAnimationFrame doNextFrame
      return

    requestAnimationFrame doNextFrame

    return

  it 'test image rendering should work even if the scene is invalid', ->

    [canvas, state] = createCanvasAndState()

    state.setShaderSource constants.VERTEX_SHADER, VSHADER_HEADER + '''
      void main() {
        blarty foo
      }
    '''

    state.setShaderSource constants.FRAGMENT_SHADER, FSHADER_HEADER + '''
      void main() {
        gl_FragColor = nark;
      }
    '''


    image = canvas.captureImage(100, 100)
    expect(image).toContain('image/png')

    return

  expectErrorsFromSource = (done, expectedErrorLines, fragmentShaderSource) ->

    [canvas, state] = createCanvasAndState()

    state.setShaderSource constants.FRAGMENT_SHADER, fragmentShaderSource

    state.on state.SHADER_ERRORS_CHANGE, (shaderType) ->
      if shaderType is constants.FRAGMENT_SHADER
        actualErrorLines = (err.line for err in state.getShaderErrors(constants.FRAGMENT_SHADER))
        expect(actualErrorLines).toEqual(expectedErrorLines)
        done()

      return

    return

  it 'should dispatch CompileStatus events on sucessful compilation', (done) ->

    expectErrorsFromSource done, [], FSHADER_HEADER + '''
      void main() {
        gl_FragColor = vec4(v_position, 1, 1);
      }
    '''

    return

  it 'should have one error if there is a syntax problem', (done) ->

    expectErrorsFromSource done, [2],  FSHADER_HEADER + '''
      void main() {
        gl_FragColor vec4(gl_FragCoord.xy / u_CanvasSize, 1, 1); // error: missing equals
      }
    '''

    return

  it 'should have multiple errors if there are multiple validation problems', (done) ->

    expectErrorsFromSource done, [2, 4],  FSHADER_HEADER + '''
      void main() {
        foo = 1.0; // first error
        gl_FragColor = vec4(v_position, 1, 1);
        bar = 2.0; // second error
      }
    '''

    return

  it 'should interpret a failed linking as a line -1 error on both shaders', (done) ->

    [canvas, state] = createCanvasAndState()

    state.setShaderSource constants.FRAGMENT_SHADER, FSHADER_HEADER + '''
      varying vec4 doesntExist; // not present in vertex shader, that's a link error
      void main() {
        gl_FragColor = doesntExist;
      }
    '''
    state.setShaderSource constants.VERTEX_SHADER, VSHADER_HEADER + '''
      void main() {
        gl_Position = vec4(0);
      }
    '''

    eventCount = 0
    state.on state.SHADER_ERRORS_CHANGE, ->

      ++eventCount

      if eventCount is 4 # two successful compiles, two failures during link
        fragErrors = state.getShaderErrors(constants.FRAGMENT_SHADER)
        expect(fragErrors.length).toEqual 1
        expect(fragErrors[0].line).toEqual -1


        vertErrors = state.getShaderErrors(constants.VERTEX_SHADER)
        expect(vertErrors.length).toEqual 1
        expect(vertErrors[0].line).toEqual -1

        done()

      return

    return


  return







