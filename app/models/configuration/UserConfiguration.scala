package models.configuration

import play.api.Play.current
import com.scalableminds.util.security.SCrypt._
import scala.collection.mutable.Stack
import play.api.libs.json.JsValue
import play.api.libs.json.JsBoolean
import play.api.libs.json._
import models.basics.BasicSettings

case class UserConfiguration(configuration: Map[String, JsValue]) {

  def configurationOrDefaults = {
    UserConfiguration.default.configuration ++ configuration
  }

}

object UserConfiguration extends BasicSettings {

  implicit val userConfigurationFormat = Json.format[UserConfiguration]

  val default = UserConfiguration(
    Map(
      "moveValue" -> JsNumber(300),
      "moveValue3d" -> JsNumber(300),
      "rotateValue" -> JsNumber(0.01),
      "crosshairSize" -> JsNumber(0.1),
      "scaleValue" -> JsNumber(0.05),
      "mouseRotateValue" -> JsNumber(0.004),
      "clippingDistance" -> JsNumber(50),
      "clippingDistanceArbitrary" -> JsNumber(64),
      "dynamicSpaceDirection" -> JsBoolean(true),
      "displayCrosshair" -> JsBoolean(true),
      "interpolation" -> JsBoolean(false),
      "brightnessContrastSettings" -> Json.obj(
        "default" -> Json.obj(
          "brightness" -> 0,
          "contrast" -> 1
        ),
        "st08x2" -> Json.obj(
          "brightness" -> 0,
          "contrast" -> 2.4
        ),
        "07x2" -> Json.obj(
          "brightness" -> 0,
          "contrast" -> 2.4
        )
      ),
      "zoom" -> JsNumber(2),
      "scale" -> JsNumber(1),
      "tdViewDisplayPlanes" -> JsBoolean(true),
      "isosurfaceDisplay" -> JsBoolean(false),
      "isosurfaceBBsize" -> JsNumber(1),
      "isosurfaceResolution" -> JsNumber(80),
      "newNodeNewTree" -> JsBoolean(false),
      "inverseX" -> JsBoolean(false),
      "inverseY" -> JsBoolean(false),
      "keyboardDelay" -> JsNumber(200),
      "mouseActive" -> JsBoolean(true),
      "keyboardActive" -> JsBoolean(true),
      "gamepadActive" -> JsBoolean(false),
      "motionsensorActive" -> JsBoolean(false),
      "firstVisToggle" -> JsBoolean(true),
      "particleSize" -> JsNumber(5),
      "overrideNodeRadius" -> JsBoolean(true),
      "sortTreesByName" -> JsBoolean(false),
      "sortCommentsAsc" -> JsBoolean(true),
      "segmentationOpacity" -> JsNumber(20),
      "sphericalCapRadius" -> JsNumber(140)))

}