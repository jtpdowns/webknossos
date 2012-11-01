package models

import com.mongodb.casbah.Imports._
import models.context._
import com.novus.salat.annotations._
import com.novus.salat.dao.SalatDAO
import models.basics.BasicDAO

case class UsedExperiments(user: ObjectId, experiment: ObjectId, _id: ObjectId = new ObjectId)

object UsedExperiments extends BasicDAO[UsedExperiments]("usedExperiments") {
  def use(user: User, experiment: Experiment) {
    removeAll(user)
    UsedExperiments.insert(UsedExperiments(user._id, experiment._id))
  }
  
  def by(user: User) = 
    find( MongoDBObject("user" -> user._id)).map(_.experiment).toList
  
  def removeAll(user: User) {
    find(MongoDBObject("user" -> user._id)).toList.foreach(UsedExperiments.remove)
  }
}