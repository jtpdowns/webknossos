### define
underscore : _
../viewmodes/plane_controller : PlaneController
###

class VolumeTacingPlaneController extends PlaneController

  # See comment in Controller class on general controller architecture.
  #
  # Volume Tracing Plane Controller:
  # Extends Plane controller to add controls that are specific to Volume
  # Tracing.


  constructor : (@model, stats, @gui, @view, @sceneController, @volumeTracingController) ->

    super(@model, stats, @gui, @view, @sceneController)


  getPlaneMouseControls : (planeId) ->

    return _.extend super(planeId),
      
      leftDownMove : (delta, pos, plane, event) =>

        if event.ctrlKey
          @move [
            delta.x * @model.user.getMouseInversionX() / @planeView.scaleFactor
            delta.y * @model.user.getMouseInversionY() / @planeView.scaleFactor
            0
          ]
        else
          @model.volumeTracing.addToLayer( @calculateGlobalPos(pos))
      
      leftMouseDown : (pos, plane, event) =>

        @volumeTracingController.enterDeleteMode( event.shiftKey )
        @model.volumeTracing.startEditing(plane)
      
      leftMouseUp : =>

        @model.volumeTracing.finishLayer()
        @volumeTracingController.restoreAfterDeleteMode()
      
      rightDownMove : (delta, pos, plane, event) =>

        @model.volumeTracing.addToLayer( @calculateGlobalPos(pos))
      
      rightMouseDown : (pos, plane, event) =>

        @volumeTracingController.enterDeleteMode()
        @model.volumeTracing.startEditing(plane)
      
      rightMouseUp : =>

        @model.volumeTracing.finishLayer()
        @volumeTracingController.restoreAfterDeleteMode()

      leftClick : (pos, plane, event) =>

        cellId = @model.binary["segmentation"].cube.getDataValue(
                  @calculateGlobalPos( pos ))

        @volumeTracingController.handleCellSelection( cellId )


  getKeyboardControls : ->

    _.extend super(),

      "c" : =>
        @model.volumeTracing.createCell()