### define 
./volumelayer : VolumeLayer
./dimensions : DimensionsHelper
###

class VolumeCell

  constructor : (@id) ->

    @layers = []            # List of VolumeLayers

  createLayer : (planeId, thirdDimensionValue) ->
    if @getLayer(planeId, thirdDimensionValue) != null
      return null
    layer = new VolumeLayer(planeId, thirdDimensionValue)
    @layers.push(layer)
    return layer

  getLayer : (planeId, thirdDimensionValue) ->
    for layer in @layers
      if layer.plane == planeId and layer.thirdDimensionValue == thirdDimensionValue
        return layer
    return null

  getVoxelArray : ->

    if @layers.length == 0
      return []

    # Get cuboid of possible voxels
    minCoord = @layers[0].minCoord.slice()
    maxCoord = @layers[0].maxCoord.slice()
    for layer in @layers
      for i in [0..2]
        minCoord[i] = Math.min(minCoord[i], @layers[0].minCoord[i])
        maxCoord[i] = Math.max(maxCoord[i], @layers[0].maxCoord[i])

    return @getVoxelArrayForCuboid(minCoord, maxCoord)

  getVoxelArrayForCuboid : (minCoord, maxCoord) ->

    res = []
    # Check every voxel in this cuboid
    for x in [minCoord[0]..maxCoord[0]]
      for y in [minCoord[1]..maxCoord[1]]
        for z in [minCoord[2]..maxCoord[2]]
          for layer in @layers
            if layer.containsVoxel([x, y, z])
              res.push([x, y, z])
              break

    return res