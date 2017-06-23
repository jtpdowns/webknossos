/*
* Copyright (C) 2011-2017 scalable minds UG (haftungsbeschränkt) & Co. KG. <http://scm.io>
*/
package com.scalableminds.braingames.datastore.controllers

import java.io.{ByteArrayOutputStream, OutputStream}
import java.util.Base64

import com.google.inject.Inject
import com.scalableminds.braingames.binary.api.BinaryDataService
import com.scalableminds.braingames.binary.models._
import com.scalableminds.braingames.binary.models.datasource.{DataLayer, DataSource, DataSourceId}
import com.scalableminds.braingames.binary.models.requests.{DataServiceRequest, DataServiceRequestSettings}
import com.scalableminds.braingames.binary.helpers.{DataSourceRepository, ThumbnailHelpers}
import com.scalableminds.braingames.datastore.models.DataRequestCollection._
import com.scalableminds.braingames.datastore.models.{DataRequest, ImageThumbnail, WebKnossosDataRequest}
import com.scalableminds.util.image.{ImageCreator, ImageCreatorParameters, JPEGWriter}
import com.scalableminds.util.tools.Fox
import play.api.i18n.{Messages, MessagesApi}
import play.api.libs.concurrent.Execution.Implicits._
import play.api.libs.iteratee.Enumerator
import play.api.libs.json.Json

class BinaryDataController @Inject()(
                                      binaryDataService: BinaryDataService,
                                      dataSourceRepository: DataSourceRepository,
                                      val messagesApi: MessagesApi
                                    ) extends Controller {

  /**
    * Handles requests for raw binary data via HTTP POST from webKnossos.
    */
  def requestViaWebKnossos(
                            dataSetName: String,
                            dataLayerName: String
                          ) = TokenSecuredAction(dataSetName, dataLayerName).async(validateJson[List[WebKnossosDataRequest]]) {
    implicit request =>
      AllowRemoteOrigin {
        requestData(dataSetName, dataLayerName, request.body).map(Ok(_))
      }
  }

  /**
    * Handles requests for raw binary data via HTTP GET for debugging.
    */
  def requestViaAjaxDebug(
                           dataSetName: String,
                           dataLayerName: String,
                           cubeSize: Int,
                           x: Int,
                           y: Int,
                           z: Int,
                           resolution: Int,
                           halfByte: Boolean
                         ) = TokenSecuredAction(dataSetName, dataLayerName).async {
    implicit request =>
      AllowRemoteOrigin {
        val request = DataRequest(
          new VoxelPosition(x, y, z, math.pow(2, resolution).toInt),
          cubeSize,
          cubeSize,
          cubeSize,
          DataServiceRequestSettings(halfByte = halfByte)
        )
        requestData(dataSetName, dataLayerName, request).map(Ok(_))
      }
  }

  /**
    * Handles a request for raw binary data via a HTTP GET. Used by knossos.
    */
  def requestViaKnossos(
                         dataSetName: String,
                         dataLayerName: String,
                         resolution: Int,
                         x: Int, y: Int, z: Int,
                         cubeSize: Int
                       ) = TokenSecuredAction(dataSetName, dataLayerName).async {
    implicit request =>
      AllowRemoteOrigin {
        val request = DataRequest(
          new VoxelPosition(x * cubeSize * resolution,
            y * cubeSize * resolution,
            z * cubeSize * resolution,
            resolution),
          cubeSize,
          cubeSize,
          cubeSize)
        requestData(dataSetName, dataLayerName, request).map(Ok(_))
      }
  }

  /**
    * Handles requests for data sprite sheets.
    */
  def requestSpriteSheet(
                          dataSetName: String,
                          dataLayerName: String,
                          cubeSize: Int,
                          imagesPerRow: Int,
                          x: Int,
                          y: Int,
                          z: Int,
                          resolution: Int,
                          halfByte: Boolean
                        ) = TokenSecuredAction(dataSetName, dataLayerName).async(parse.raw) {
    implicit request =>
      AllowRemoteOrigin {
        val request = DataRequest(
          new VoxelPosition(x, y, z, math.pow(2, resolution).toInt),
          cubeSize,
          cubeSize,
          cubeSize,
          DataServiceRequestSettings(halfByte = halfByte))

        for {
          imageProvider <- respondWithSpriteSheet(dataSetName, dataLayerName, request, imagesPerRow, blackAndWhite = false)
        } yield {
          Ok.stream(Enumerator.outputStream(imageProvider).andThen(Enumerator.eof)).withHeaders(
            CONTENT_TYPE -> contentTypeJpeg,
            CONTENT_DISPOSITION -> "filename=test.jpg")
        }
      }
  }

  /**
    * Handles requests for data images.
    */
  def requestImage(
                    dataSetName: String,
                    dataLayerName: String,
                    width: Int,
                    height: Int,
                    x: Int,
                    y: Int,
                    z: Int,
                    resolution: Int,
                    halfByte: Boolean,
                    blackAndWhite: Boolean) = TokenSecuredAction(dataSetName, dataLayerName).async(parse.raw) {
    implicit request =>
      AllowRemoteOrigin {
        val request = DataRequest(
          new VoxelPosition(x, y, z, math.pow(2, resolution).toInt),
          width,
          height,
          1,
          DataServiceRequestSettings(halfByte = halfByte))

        for {
          imageProvider <- respondWithSpriteSheet(dataSetName, dataLayerName, request, 1, blackAndWhite)
        } yield {
          Ok.stream(Enumerator.outputStream(imageProvider).andThen(Enumerator.eof)).withHeaders(
            CONTENT_TYPE -> contentTypeJpeg,
            CONTENT_DISPOSITION -> "filename=test.jpg")
        }
      }
  }

  /**
    * Handles requests for dataset thumbnail images as JPEG.
    */
  def requestImageThumbnailJpeg(
                                 dataSetName: String,
                                 dataLayerName: String,
                                 width: Int,
                                 height: Int) = TokenSecuredAction(dataSetName, dataLayerName).async(parse.raw) {
    implicit request =>
      AllowRemoteOrigin {
        for {
          thumbnailProvider <- respondWithImageThumbnail(dataSetName, dataLayerName, width, height)
        } yield {
          Ok.stream(Enumerator.outputStream(thumbnailProvider).andThen(Enumerator.eof)).withHeaders(
            CONTENT_TYPE -> contentTypeJpeg,
            CONTENT_DISPOSITION -> "filename=thumbnail.jpg")
        }
      }
  }

  /**
    * Handles requests for dataset thumbnail images as base64-encoded JSON.
    */
  def requestImageThumbnailJson(
                                 dataSetName: String,
                                 dataLayerName: String,
                                 width: Int,
                                 height: Int
                               ) = TokenSecuredAction(dataSetName, dataLayerName).async(parse.raw) {
    implicit request =>
      AllowRemoteOrigin {
        for {
          thumbnailProvider <- respondWithImageThumbnail(dataSetName, dataLayerName, width, height)
        } yield {
          val os = new ByteArrayOutputStream()
          thumbnailProvider(Base64.getEncoder.wrap(os))
          Ok(Json.toJson(ImageThumbnail(contentTypeJpeg, os.toString)))
        }
      }
  }

  private def getDataSourceAndDataLayer(dataSetName: String, dataLayerName: String): Fox[(DataSource, DataLayer)] = {
    for {
      dataSource <- dataSourceRepository.findUsableByName(dataSetName).toFox ?~> Messages("dataSource.notFound") ~> 404
      dataLayer <- dataSource.getDataLayer(dataLayerName).toFox ?~> Messages("dataLayer.notFound") ~> 404
    } yield {
      (dataSource, dataLayer)
    }
  }

  private def requestData(
                           dataSetName: String,
                           dataLayerName: String,
                           dataRequests: DataRequestCollection
                         ): Fox[Array[Byte]] = {
    for {
      (dataSource, dataLayer) <- getDataSourceAndDataLayer(dataSetName, dataLayerName)
      requests = dataRequests.map(r => DataServiceRequest(dataSource, dataLayer, r.cuboid, r.settings))
      data <- binaryDataService.handleDataRequests(requests)
    } yield {
      data
    }
  }

  private def contentTypeJpeg = play.api.libs.MimeTypes.forExtension("jpeg").getOrElse(play.api.http.ContentTypes.BINARY)

  private def respondWithSpriteSheet(
                                      dataSetName: String,
                                      dataLayerName: String,
                                      request: DataRequest,
                                      imagesPerRow: Int,
                                      blackAndWhite: Boolean
                                    ): Fox[(OutputStream) => Unit] = {
    for {
      (_, dataLayer) <- getDataSourceAndDataLayer(dataSetName, dataLayerName)
      params = ImageCreatorParameters(
        dataLayer.bytesPerElement,
        request.settings.halfByte,
        request.cuboid.width,
        request.cuboid.height,
        imagesPerRow,
        blackAndWhite = blackAndWhite)
      data <- requestData(dataSetName, dataLayerName, request)
      spriteSheet <- ImageCreator.spriteSheetFor(data, params) ?~> Messages("image.create.failed")
      firstSheet <- spriteSheet.pages.headOption ?~> Messages("image.page.failed")
    } yield {
      new JPEGWriter().writeToOutputStream(firstSheet.image)
    }
  }

  private def respondWithImageThumbnail(
                                     dataSetName: String,
                                     dataLayerName: String,
                                     width: Int,
                                     height: Int
                                   ): Fox[(OutputStream) => Unit] = {
    for {
      (_, dataLayer) <- getDataSourceAndDataLayer(dataSetName, dataLayerName)
      position = ThumbnailHelpers.goodThumbnailParameters(dataLayer, width, height)
      request = DataRequest(position, width, height, 1)
      image <- respondWithSpriteSheet(dataSetName, dataLayerName, request, 1, blackAndWhite = false)
    } yield {
      image
    }
  }
}
