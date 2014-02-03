### define
jquery : $
underscore : _
libs/event_mixin : EventMixin
libs/request : Request
libs/input : Input
../../geometries/arbitrary_plane : ArbitraryPlane
../../geometries/crosshair : Crosshair
../../view/arbitrary_view : ArbitraryView
../../geometries/arbitrary_plane_info : ArbitraryPlaneInfo
../../constants : constants
###

class ArbitraryController

  # See comment in Controller class on general controller architecture.
  #
  # Arbitrary Controller: Responsible for Arbitrary Modes

  WIDTH : 128
  HEIGHT : 128

  plane : null
  crosshair : null
  cam : null

  fullscreen : false
  lastNodeMatrix : null

  model : null
  view : null

  record : false

  input :
    mouse : null
    keyboard : null
    keyboardNoLoop : null
    keyboardOnce : null

    unbind : ->

      @mouse?.unbind()
      @keyboard?.unbind()
      @keyboardNoLoop?.unbind()
      @keyboardOnce?.unbind()


  constructor : (@model, stats, @gui, @view, @sceneController) ->

    _.extend(this, new EventMixin())

    @isStarted = false

    @canvas = canvas = $("#render-canvas")
    
    @cam = @model.flycam3d
    @arbitraryView = new ArbitraryView(canvas, @cam, stats, @view, @model.scaleInfo)

    @plane = new ArbitraryPlane(@cam, @model, @WIDTH, @HEIGHT)
    @arbitraryView.addGeometry @plane

    @infoPlane = new ArbitraryPlaneInfo()

    @input = _.extend({}, @input)

    @crosshair = new Crosshair(@cam, model.user.crosshairSize)
    @arbitraryView.addGeometry(@crosshair)

    @bind()
    @arbitraryView.draw()

    @stop()


  render : (forceUpdate, event) ->

    matrix = @cam.getMatrix()
    @model.binary["color"].arbitraryPing(matrix)


  initMouse : ->

    @input.mouse = new Input.Mouse(
      @canvas
      leftDownMove : (delta) =>
        if @mode == constants.MODE_ARBITRARY
          @cam.yaw(
            -delta.x * @model.user.getMouseInversionX() * @model.user.mouseRotateValue,
            true )
          @cam.pitch(
            delta.y * @model.user.getMouseInversionY() * @model.user.mouseRotateValue,
            true )
        else if @mode == constants.MODE_ARBITRARY_PLANE
          f = @cam.getZoomStep() / (@arbitraryView.width / @WIDTH)
          @cam.move [delta.x * f, delta.y * f, 0]
      scroll : @scroll
    )


  initKeyboard : ->

    getVoxelOffset  = (timeFactor) =>

      return @model.user.moveValue3d * timeFactor / @model.scaleInfo.baseVoxel / constants.FPS
    
    
    @input.keyboard = new Input.Keyboard(
 
      #Scale plane
      "l"             : (timeFactor) => @arbitraryView.applyScale -@model.user.scaleValue
      "k"             : (timeFactor) => @arbitraryView.applyScale  @model.user.scaleValue

      #Move   
      "w"             : (timeFactor) => @cam.move [0, getVoxelOffset(timeFactor), 0]
      "s"             : (timeFactor) => @cam.move [0, -getVoxelOffset(timeFactor), 0]
      "a"             : (timeFactor) => @cam.move [getVoxelOffset(timeFactor), 0, 0]
      "d"             : (timeFactor) => @cam.move [-getVoxelOffset(timeFactor), 0, 0]
      "space"         : (timeFactor) =>  
        @cam.move [0, 0, getVoxelOffset(timeFactor)]
        @moved()
      "alt + space"   : (timeFactor) => @cam.move [0, 0, -getVoxelOffset(timeFactor)]
      
      #Rotate in distance
      "left"          : (timeFactor) => @cam.yaw @model.user.rotateValue * timeFactor, @mode == constants.MODE_ARBITRARY
      "right"         : (timeFactor) => @cam.yaw -@model.user.rotateValue * timeFactor, @mode == constants.MODE_ARBITRARY
      "up"            : (timeFactor) => @cam.pitch -@model.user.rotateValue * timeFactor, @mode == constants.MODE_ARBITRARY
      "down"          : (timeFactor) => @cam.pitch @model.user.rotateValue * timeFactor, @mode == constants.MODE_ARBITRARY
      
      #Rotate at centre
      "shift + left"  : (timeFactor) => @cam.yaw @model.user.rotateValue * timeFactor
      "shift + right" : (timeFactor) => @cam.yaw -@model.user.rotateValue * timeFactor
      "shift + up"    : (timeFactor) => @cam.pitch @model.user.rotateValue * timeFactor
      "shift + down"  : (timeFactor) => @cam.pitch -@model.user.rotateValue * timeFactor

      #Zoom in/out
      "i"             : (timeFactor) => @cam.zoomIn()
      "o"             : (timeFactor) => @cam.zoomOut()

      #Change move value
      "h"             : (timeFactor) => @changeMoveValue(25)
      "g"             : (timeFactor) => @changeMoveValue(-25)
    )
    
    @input.keyboardNoLoop = new Input.KeyboardNoLoop(

      "1" : => @sceneController.skeleton.toggleVisibility()
      "2" : => @sceneController.skeleton.toggleInactiveTreeVisibility()

      #Delete active node
      "delete" : => @model.skeletonTracing.deleteActiveNode()
      "c" : => @model.skeletonTracing.createNewTree()
      
      #Branches
      "b" : => @pushBranch()
      "j" : => @popBranch() 
      
      #Reset Matrix
      "r" : => @cam.resetRotation()

      #Recenter active node
      "y" : => @centerActiveNode()

      #Recording of Waypoints
      "z" : => 
        @record = true
        @infoPlane.updateInfo(true)
        @setWaypoint()
      "u" : => 
        @record = false
        @infoPlane.updateInfo(false)
      #Comments
      "n" : => @setActiveNode(@model.skeletonTracing.nextCommentNodeID(false), true)
      "p" : => @setActiveNode(@model.skeletonTracing.nextCommentNodeID(true), true)
    )

    @input.keyboardOnce = new Input.Keyboard(

      #Delete active node and recenter last node
      "shift + space" : =>
        @model.skeletonTracing.deleteActiveNode()
        @centerActiveNode()
        
    , -1)

  init : ->

    @setClippingDistance @model.user.clippingDistance
    @arbitraryView.applyScale(0)


  bind : ->

    @arbitraryView.on "render", (force, event) => @render(force, event)
    @arbitraryView.on "finishedRender", => @model.skeletonTracing.rendered()

    @model.binary["color"].cube.on "bucketLoaded", => @arbitraryView.draw()

    @model.user.on "crosshairSizeChanged", (value) =>
      @crosshair.setScale(value)

    @model.user.on "clippingDistanceArbitraryChanged", (value) =>
      @setClippingDistance(value)


  start : (@mode) ->

    @stop()

    if @mode == constants.MODE_ARBITRARY
      @plane.queryVertices = @plane.queryVerticesSphere
    else if @mode == constants.MODE_ARBITRARY_PLANE
      @plane.queryVertices = @plane.queryVerticesPlane
    @plane.isDirty = true

    @initKeyboard()
    @initMouse()
    @arbitraryView.start()
    @init()
    @arbitraryView.draw()   

    @isStarted = true 
 

  stop : ->

    if @isStarted
      @input.unbind()
    
    @arbitraryView.stop()

    @isStarted = false


  scroll : (delta, type) =>

    switch type
      when "shift" then @setParticleSize(delta)


  addNode : (position) =>

    @model.skeletonTracing.addNode(position, constants.TYPE_USUAL)


  setWaypoint : () =>

    unless @record 
      return

    position  = @cam.getPosition()
    activeNodePos = @model.skeletonTracing.getActiveNodePos()

    @addNode(position)

  changeMoveValue : (delta) ->

    moveValue = @model.user.moveValue3d + delta
    moveValue = Math.min(constants.MAX_MOVE_VALUE, moveValue)
    moveValue = Math.max(constants.MIN_MOVE_VALUE, moveValue)

    @model.user.setValue("moveValue3d", (Number) moveValue)


  setParticleSize : (delta) =>

    particleSize = @model.user.particleSize + delta
    particleSize = Math.min(constants.MAX_PARTICLE_SIZE, particleSize)
    particleSize = Math.max(constants.MIN_PARTICLE_SIZE, particleSize)

    @model.user.setValue("particleSize", (Number) particleSize)


  setClippingDistance : (value) =>

    @arbitraryView.setClippingDistance(value)


  pushBranch : ->

    @model.skeletonTracing.pushBranch()


  popBranch : ->

    _.defer => @model.skeletonTracing.popBranch().done((id) => 
      @setActiveNode(id, true)
    )


  centerActiveNode : ->

    activeNode = @model.skeletonTracing.getActiveNode()
    if activeNode
      @cam.setPosition(activeNode.pos)
      parent = activeNode.parent
      while parent
        # set right direction
        direction = ([
          activeNode.pos[0] - parent.pos[0],
          activeNode.pos[1] - parent.pos[1],
          activeNode.pos[2] - parent.pos[2]])
        if direction[0] or direction[1] or direction[2]
          @cam.setDirection( @model.scaleInfo.voxelToNm( direction ))
          break
        parent = parent.parent


  setActiveNode : (nodeId, centered, mergeTree) ->

    @model.skeletonTracing.setActiveNode(nodeId, mergeTree)
    @cam.setPosition @model.skeletonTracing.getActiveNodePos()  


  moved : ->

    matrix = @cam.getMatrix()

    unless @lastNodeMatrix?
      @lastNodeMatrix = matrix

    lastNodeMatrix = @lastNodeMatrix

    vector = [
      lastNodeMatrix[12] - matrix[12]
      lastNodeMatrix[13] - matrix[13]
      lastNodeMatrix[14] - matrix[14]
    ]
    vectorLength = V3.length(vector)

    if vectorLength > 10
      @setWaypoint()
      @lastNodeMatrix = matrix    