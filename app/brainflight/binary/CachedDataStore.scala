package brainflight.binary

import brainflight.tools.geometry.Point3D
import play.api.Play.current
import play.api.Play
import brainflight.tools.geometry.Point3D
import models.binary._
import java.io.{ FileNotFoundException, InputStream, FileInputStream, File }
import akka.agent.Agent
import brainflight.tools.geometry.Vector3D
import brainflight.tools.Interpolator
import play.api.Logger
import brainflight.tools.Math._

case class DataBlock(info: DataBlockInformation, data: Data)

case class DataBlockInformation(
  dataSetId: String,
  dataLayer: DataLayer,
  resolution: Int,
  block: Point3D)

case class Data(value: Array[Byte])

/**
 * A data store implementation which uses the hdd as data storage
 */
abstract class CachedDataStore(cacheAgent: Agent[Map[DataBlockInformation, Data]]) extends DataStore {

  // defines the maximum count of cached file handles
  val maxCacheSize = conf.getInt("bindata.cacheMaxSize") getOrElse 100

  // defines how many file handles are deleted when the limit is reached
  val dropCount = conf.getInt("bindata.cacheDropCount") getOrElse 20

  var lastUsed: Option[Tuple2[DataBlockInformation, Data]] = None

  /**
   * Uses the coordinates of a point to calculate the data block the point
   * lays in.
   */
  def PointToBlock(point: Point3D, resolution: Int) =
    Point3D(
      point.x / blockLength / resolution,
      point.y / blockLength / resolution,
      point.z / blockLength / resolution)

  def GlobalToLocal(point: Point3D, resolution: Int) =
    Point3D(
      (point.x / resolution) % blockLength,
      (point.y / resolution) % blockLength,
      (point.z / resolution) % blockLength)

  def useLastUsed(blockInfo: DataBlockInformation) = {
    lastUsed.flatMap {
      case (info, data) if info == blockInfo =>
        Some(data)
      case _ =>
        None
    }
  }

  override def load(dataRequest: DataRequest): Array[Byte] = {
    def loadFromSomewhere(dataSet: DataSet, dataLayer: DataLayer, resolution: Int, block: Point3D): Array[Byte] = {
      val blockInfo = DataBlockInformation(dataSet.id, dataLayer, resolution, block)

      val byteArray: Array[Byte] =
        ((useLastUsed(blockInfo) orElse cacheAgent().get(blockInfo)).map(
          d => d.value) getOrElse (
            loadAndCacheData(dataSet, dataLayer, resolution, block).value))

      lastUsed = Some(blockInfo -> Data(byteArray))
      byteArray
    }

    val t = System.currentTimeMillis()

    val cube = dataRequest.cuboid

    val maxCorner = cube.maxCorner

    val minCorner = cube.minCorner

    val minPoint = Point3D(math.max(minCorner._1 - 1, 0).toInt, math.max(minCorner._2 - 1, 0).toInt, math.max(minCorner._3 - 1, 0).toInt)

    val minBlock = PointToBlock(minPoint, dataRequest.resolution)
    val maxBlock = PointToBlock(Point3D(maxCorner._1.ceil.toInt + 1, maxCorner._2.ceil.toInt + 1, maxCorner._3.ceil.toInt + 1), dataRequest.resolution)

    var blockPoints: List[Point3D] = Nil
    var blockData: List[Array[Byte]] = Nil

    for {
      x <- minBlock.x to maxBlock.x
      y <- minBlock.y to maxBlock.y
      z <- minBlock.z to maxBlock.z
    } {
      val p = Point3D(x, y, z)
      blockPoints ::= p
      blockData ::= loadFromSomewhere(
        dataRequest.dataSet,
        dataRequest.layer,
        dataRequest.resolution,
        p)
    }

    Logger.debug("loadFromSomewhere: %d ms".format(System.currentTimeMillis() - t))
    val blockMap = blockPoints.zip(blockData).toMap

    val interpolate = dataRequest.layer.interpolate(dataRequest.resolution, blockMap, getBytes _) _

    val result = cube.withContainingCoordinates(extendArrayBy = dataRequest.layer.bytesPerElement) {
      case point =>
        // TODO: Remove Wrapper
        interpolate(Vector3D(point))
    }

    Logger.debug("loading&interp: %d ms, Sum: ".format(System.currentTimeMillis() - t, result.sum))
    result
  }

  def getBytes(globalPoint: Point3D, bytesPerElement: Int, resolution: Int, blockMap: Map[Point3D, Array[Byte]]): Array[Byte] = {
    val block = PointToBlock(globalPoint, resolution)
    blockMap.get(block) match {
      case Some(byteArray) =>
        getLocalBytes(GlobalToLocal(globalPoint, resolution), bytesPerElement, byteArray)
      case _ =>
        println("Didn't find block! :(")
        nullValue(bytesPerElement)
    }
  }

  def getLocalBytes(localPoint: Point3D, bytesPerElement: Int, data: Array[Byte]): Array[Byte] = {

    val address = (localPoint.x + localPoint.y * 128 + localPoint.z * 128 * 128) * bytesPerElement
    if (address > data.size)
      Logger.info("address: %d , Point: (%d, %d, %d), EPB: %d, dataSize: %d".format(address, localPoint.x, localPoint.y, localPoint.z, bytesPerElement, data.size))
    val bytes = new Array[Byte](bytesPerElement)
    var i = 0
    while (i < bytesPerElement) {
      bytes.update(i, data(address + i))
      i += 1
    }
    bytes
  }

  /**
   * Loads the due to x,y and z defined block into the cache array and
   * returns it.
   */
  def loadBlock(dataSet: DataSet, dataLayer: DataLayer, resolution: Int, point: Point3D): DataBlock

  def loadAndCacheData(dataSet: DataSet, dataLayer: DataLayer, resolution: Int, point: Point3D): Data = {
    val block = loadBlock(dataSet, dataLayer, resolution, point)
    cacheAgent send (_ + (block.info -> block.data))
    block.data
  }

  /**
   * Function to restrict the cache to a maximum size. Should be
   * called before or after an item got inserted into the cache
   */
  def ensureCacheMaxSize {
    // pretends to flood memory with to many files
    if (cacheAgent().size > maxCacheSize)
      cacheAgent send (_.drop(dropCount))
  }

  /**
   *  Read file contents to a byteArray
   */
  def inputStreamToByteArray(is: InputStream, bytesPerElement: Int) = {
    val byteCount = elementsPerFile * bytesPerElement
    val byteArray = new Array[Byte](byteCount)
    is.read(byteArray, 0, byteCount)
    //assert(is.skip(1) == 0, "INPUT STREAM NOT EMPTY")
    byteArray
  }

  /**
   * Called when the store is restarted or going to get shutdown.
   */
  def cleanUp() {
    cacheAgent send (_ => Map.empty)
  }

}
