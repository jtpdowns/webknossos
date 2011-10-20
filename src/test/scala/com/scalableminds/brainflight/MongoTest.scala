package com.scalableminds.brainflight

import model.ProtoUser
import org.specs.Specification
import bootstrap.liftweb.Boot
import net.liftweb.mongodb._
import com.mongodb.BasicDBObject

import com.foursquare.rogue.Rogue._
import com.foursquare.rogue._

/**
 * Created by IntelliJ IDEA.
 * User: lesnail
 * Date: 19.10.11
 * Time: 17:58
 * To change this template use File | Settings | File Templates.
 */

object MongoTest extends Specification{
  "Mongos" should{
    "be" in{

      val b = new Boot()
      b.boot
      MongoDB.use(DefaultMongoIdentifier) ( db => {
      val coll = db.getCollection("testCollection")
      coll.drop()
      val doc = new BasicDBObject()
      doc.put("muh","1")
      coll.save(doc)
      coll.findOne must_== doc
      coll.remove(doc)
      val rec = ProtoUser.createRecord.userName("tom").email("tom5@bla.de").password("homo").save
      //val pk = MyPk.createRecord.keyA("a").keyB("b")
      //val rec = User.createRecord.id(pk).save
      })
    }
  }
}