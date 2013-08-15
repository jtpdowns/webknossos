package controllers

import oxalis.security.Secured
import play.api.mvc.Action
import play.api._
import play.api.libs.concurrent.Akka
import akka.actor.Props
import braingames.mail.Mailer
import braingames.mvc.Controller

object Application extends Controller with Secured {
  override val DefaultAccessRole = None
  lazy val app = play.api.Play.current

  lazy val Mailer =
    Akka.system(app).actorFor("/user/mailActor")

  lazy val annotationStore =
    Akka.system(app).actorFor("/user/annotationStore")

  // -- Javascript routing

  def javascriptRoutes = Action { implicit request =>
    Ok(
      Routes.javascriptRouter("jsRoutes")( //fill in stuff which should be able to be called from js
        controllers.admin.routes.javascript.NMLIO.upload,


        controllers.admin.routes.javascript.AnnotationAdministration.annotationsForTask,
        controllers.admin.routes.javascript.TaskAdministration.edit,
        controllers.routes.javascript.AnnotationController.trace,
        controllers.admin.routes.javascript.NMLIO.taskDownload,
        controllers.admin.routes.javascript.TrainingsTaskAdministration.create,
        controllers.admin.routes.javascript.TaskAdministration.delete

        )).as("text/javascript")
  }

  def impressum = Authenticated{ implicit request =>
    Ok(views.html.impressum())
  }
}