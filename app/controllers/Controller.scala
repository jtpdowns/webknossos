package controllers

import com.scalableminds.webknossos.datastore.controllers.ValidationHelpers
import com.scalableminds.util.mvc.ExtendedController
import com.scalableminds.util.tools.{Converter, Fox}
import com.typesafe.scalalogging.LazyLogging
import models.basics.Implicits
import models.binary.DataSet
import models.user.User
import net.liftweb.common.{Box, Failure, Full, ParamFailure}
import oxalis.security._
import oxalis.view.ProvidesSessionData
import play.api.i18n.{I18nSupport, Messages, MessagesApi}
import play.api.libs.concurrent.Execution.Implicits._
import play.api.libs.json._
import play.api.mvc.{Request, Result, Controller => PlayController}
import play.twirl.api.Html
import oxalis.security.WebknossosSilhouette.{SecuredAction, SecuredRequest, UserAwareAction, UserAwareRequest}
import reactivemongo.bson.BSONObjectID
import utils.ObjectId


trait Controller extends PlayController
  with ExtendedController
  with ProvidesSessionData
  with models.basics.Implicits
  with ValidationHelpers
  with I18nSupport
  with LazyLogging {

  implicit def AuthenticatedRequest2Request[T](r: SecuredRequest[T]): Request[T] =
    r.request

  def ensureTeamAdministration(user: User, teamId: ObjectId): Fox[Unit] =
    for {
      teamIdBson <- teamId.toBSONObjectId.toFox
      _ <- ensureTeamAdministration(user, teamIdBson)
    } yield ()

  def ensureTeamAdministration(user: User, team: BSONObjectID): Fox[Unit] =
    user.assertTeamManagerOrAdminOf(team) ?~> Messages("team.admin.notAllowed")

  def allowedToAdministrate(admin: User, dataSet: DataSet) =
    dataSet.isEditableBy(Some(admin)) ?~> Messages("notAllowed")

  case class Filter[A, T](name: String, predicate: (A, T) => Boolean, default: Option[String] = None)(implicit converter: Converter[String, A]) {
    def applyOn(list: List[T])(implicit request: Request[_]): List[T] = {
      request.getQueryString(name).orElse(default).flatMap(converter.convert) match {
        case Some(attr) => list.filter(predicate(attr, _))
        case _          => list
      }
    }
  }

  case class FilterColl[T](filters: Seq[Filter[_, T]]) {
    def applyOn(list: List[T])(implicit request: Request[_]): List[T] = {
      filters.foldLeft(list) {
        case (l, filter) => filter.applyOn(l)
      }
    }
  }

  def UsingFilters[T, R](filters: Filter[_, T]*)(block: FilterColl[T] => R): R = {
    block(FilterColl(filters))
  }

  def jsonErrorWrites(errors: JsError): JsObject =
    Json.obj(
      "errors" -> errors.errors.map(error =>
        error._2.foldLeft(Json.obj("field" -> error._1.toJsonString)) {
          case (js, e) => js ++ Json.obj("error" -> Messages(e.message))
        }
      )
    )

  def withJsonBodyAs[A](f: A => Fox[Result])(implicit rds: Reads[A], request: Request[JsValue]): Fox[Result] = {
    withJsonBodyUsing(rds)(f)
  }

  def withJsonBodyUsing[A](reads: Reads[A])(f: A => Fox[Result])(implicit request: Request[JsValue]): Fox[Result] = {
    withJsonUsing(request.body, reads)(f)
  }

  def withJsonAs[A](json: JsReadable)(f: A => Fox[Result])(implicit rds: Reads[A]): Fox[Result] = {
    withJsonUsing(json, rds)(f)
  }

  def withJsonUsing[A](json: JsReadable, reads: Reads[A])(f: A => Fox[Result]): Fox[Result] = {
    json.validate(reads) match {
      case JsSuccess(result, _) =>
        f(result)
      case e: JsError           =>
        Fox.successful(JsonBadRequest(jsonErrorWrites(e), Messages("format.json.invalid")))
    }
  }
}
