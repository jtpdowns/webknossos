package models.annotation

import javax.management.relation.Role
import models.user.User
import play.api.libs.json._
import models.annotation.AnnotationState._
import utils.ObjectId

/**
 * Company: scalableminds
 * User: tmbo
 * Date: 02.06.13
 * Time: 02:02
 */

class AnnotationRestrictions {
  def allowAccess(user: Option[User]): Boolean = false

  def allowUpdate(user: Option[User]): Boolean = false

  def allowFinish(user: Option[User]): Boolean = false

  def allowDownload(user: Option[User]): Boolean = allowAccess(user)

  def allowAccess(user: User): Boolean = allowAccess(Some(user))

  def allowUpdate(user: User): Boolean = allowUpdate(Some(user))

  def allowFinish(user: User): Boolean = allowFinish(Some(user))

  def allowDownload(user: User): Boolean = allowDownload(Some(user))
}

object AnnotationRestrictions {
  def writeAsJson(ar: AnnotationRestrictions, u: Option[User]) : JsObject =
    Json.obj(
      "allowAccess" -> ar.allowAccess(u),
      "allowUpdate" -> ar.allowUpdate(u),
      "allowFinish" -> ar.allowFinish(u),
      "allowDownload" -> ar.allowDownload(u))

  def restrictEverything =
    new AnnotationRestrictions()

  def defaultAnnotationRestrictions(annotation: AnnotationSQL) =
    new AnnotationRestrictions {
      override def allowAccess(user: Option[User]) = {
        annotation.isPublic || user.exists {
          user =>
            annotation._user == ObjectId.fromBsonId(user._id) || annotation._team.toBSONObjectId.map(user.isTeamManagerOfBLOCKING(_)).getOrElse(false)
        }
      }

      override def allowUpdate(user: Option[User]) = {
        user.exists {
          user =>
            annotation._user == ObjectId.fromBsonId(user._id) && !(annotation.state == Finished)
        }
      }

      override def allowFinish(user: Option[User]) = {
        user.exists {
          user =>
            (annotation._user == ObjectId.fromBsonId(user._id) || annotation._team.toBSONObjectId.map(user.isTeamManagerOfBLOCKING(_)).getOrElse(false)) && !(annotation.state == Finished)
        }
      }
    }

  def readonlyAnnotation() =
    new AnnotationRestrictions {
      override def allowAccess(user: Option[User]) = true
    }

  def updateableAnnotation() =
    new AnnotationRestrictions {
      override def allowAccess(user: Option[User]) = true
      override def allowUpdate(user: Option[User]) = true
      override def allowFinish(user: Option[User]) = true
    }
}
