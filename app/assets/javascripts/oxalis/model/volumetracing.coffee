### define 
./volumecell : VolumeCell
./volumelayer : VolumeLayer
../../libs/event_mixin : EventMixin
./dimensions : Dimensions
###

class VolumeTracing

  constructor : (@flycam, @cube) ->
    _.extend(@, new EventMixin())

    @cells        = []          # List of VolumeCells
    @activeCell   = null        # Cell currently selected
    @currentLayer = null        # Layer currently edited
    @idCount      = 1

  createCell : ->
    @activeCell = new VolumeCell(@idCount++)
    @currentLayer = null
    @cells.push(@activeCell)

  startEditing : (planeId = @flycam.getActivePlane()) ->
    # Return, if layer was actually started
    if currentLayer?
      return false
    # just for testing
    unless @activeCell?
      @createCell()
    pos = Dimensions.roundCoordinate(@flycam.getPosition())
    thirdDimValue = pos[Dimensions.thirdDimensionForPlane(planeId)]
    @currentLayer = new VolumeLayer(planeId, thirdDimValue)
    return true

  addToLayer : (pos) ->

    unless @currentLayer?
      return

    pos = Dimensions.roundCoordinate(pos)
    @currentLayer.addContour(pos)
    @trigger "newContour", pos

  finishLayer : ->
    unless @currentLayer?
      return

    iterator = @currentLayer.getVoxelIterator()
    @cube.labelVoxels(iterator, @activeCell.id % 6 + 1)

    @currentLayer = null
    @flycam.hasChanged = true

    @trigger "resetContour"
