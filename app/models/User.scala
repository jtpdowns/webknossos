package models

import play.api.db._
import play.api.Play.current
import com.mongodb.casbah.Imports._
import models.context._
import com.novus.salat.annotations._
import com.novus.salat.dao.SalatDAO
import brainflight.security.SCrypt._
import scala.collection.mutable.Stack
import play.api.libs.json.JsValue
import play.api.libs.json.Json._
import scala.collection.immutable.HashMap
import models.basics.BasicDAO

case class User(
    email: String,
    name: String,
    verified: Boolean = false,
    pwdHash: String = "",
    loginType: String = "local",
    configuration: UserConfiguration = UserConfiguration.defaultConfiguration,
    roles: Set[String] = Set.empty,
    permissions: List[Permission] = Nil,
    _id: ObjectId = new ObjectId ) {

  val _roles = for{
    roleName <- roles
    role <- Role.findOneByName(roleName)
  } yield role
  
  val ruleSet: List[Implyable] = 
    ( permissions ++ _roles )

  
  def hasRole( role: Role ) = 
    _roles.find( _.name == role.name ).isDefined

  def hasPermission( permission: Permission ) =
    ruleSet.find( _.implies( permission ) ).isDefined
  
  override def toString = email
  
  def id = _id.toString
}

object User extends BasicDAO[User]( "users" ) {
  
  def default = findLocalByEmail( "scmboy@scalableminds.com" ).get

  val LocalLoginType = "local"
  
  def findOneByEmail( email: String ) = findOne( MongoDBObject(
    "email" -> email ) )
  
  def findLocalByEmail( email: String ) = findOne( MongoDBObject(
    "email" -> email, "loginType" -> LocalLoginType ) )
  
  
  def authRemote( email: String, loginType: String) = 
    findOne( MongoDBObject( "email" -> email, "loginType" -> loginType ) )

  def auth( email: String, password: String ) =
    for {
      user <- findOne( MongoDBObject( "email" -> email, "loginType" -> LocalLoginType ) )
      if verifyPassword( password, user.pwdHash )
    } yield user

  def create( email: String, name: String, password: String = "") = {
    alterAndInsert(User( email, name, false, hashPassword( password ) ))
  }
    
  def verify( user: User ) = {
    alterAndSave(user.copy( verified = true, roles = user.roles + "user" ))
  }
  
  def addRole( user: User, role: String) = {
    alterAndSave(user.copy( roles = user.roles + role ))
  }

  def createRemote( email: String, name: String, loginType: String ) = {
    alterAndInsert(User( email, name, true, "", loginType = loginType ))
  }
}