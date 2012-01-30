package controllers

import play.api._
import play.api.mvc._
import play.api.data._
import play.api.libs.json.Json._
import models._
import views._
import brainflight.binary._
import java.nio.ByteBuffer
import akka.actor._
import akka.util.duration._
import play.api.Play.current
import play.api.libs.iteratee._
import Input.EOF
import play.api.libs.concurrent._
import brainflight.tools.ExtendedDataTypes._
import brainflight.tools.Math._
import brainflight.tools.geometry.Vector3D._
import brainflight.tools.geometry.Figure
import play.api.libs.concurrent._

/**
 * scalableminds - brainflight
 * User: tmbo
 * Date: 11.12.11
 * Time: 13:21
 */

object BinaryData extends Controller with Secured {
  /*def data( modelType: String, px: String, py: String, pz: String, 
      ax: String, ay: String, az: String ) = Action {
    
    val axis = ( ax.toDouble, ay.toDouble, az.toDouble )
    val point = ( px.toDouble, py.toDouble, pz.toDouble )
    ( ModelStore( modelType ), axis ) match {
      case ( _, ( 0, 0, 0 ) ) =>
        BadRequest( "Axis is not allowed to be (0,0,0)." )
      case ( Some( m ), _ ) =>
        Ok( ( m.rotateAndMove( point, axis ).map( DataStore.load ).toArray ) )
      case _ =>
        NotFound( "Model not available." )
    }
  }*/

  /**
   * Websocket implementation. Client needs to send a 4 byte handle and a 64
   * byte matrix. This matrix is used to apply a helmert transformation on the
   * model. After that the requested data is resolved and pushed back to the
   * output channel. The answer on the socket consists of the 4 byte handle and
   * the result data
   *
   * @param
   * 	modelType:	id of the model to use
   */
  def dataWebsocket( modelType: String ) = WebSocket.using[Array[Byte]] { request =>
    val output = new PushEnumerator[Array[Byte]]
    val input = Iteratee.foreach[Array[Byte]]( in => {
      println( "Message arrived! Bytes: %d".format( in.length ) )
      // first 4 bytes are always used as a client handle
      if ( in.length >= 68 && in.length % 4 == 0 ) {
        val ( binHandle, inRest ) = in.splitAt( 4 )

        val ( binMatrix, binClientCoord ) = inRest.splitAt( 64 )

        // convert the matrix from byte to float representation
        val matrix = binMatrix.reverse.subDivide( 4 ).map( _.toFloat )
        val clientCoord = binClientCoord.reverse.subDivide( 4 ).map( _.toFloat ).map(_.toInt)
        ModelStore( modelType ) match {
          case Some( model ) =>
            val figure = Figure( model.polygons.map( _.rotateAndMove( matrix ) ) )
            val coordinates = pointsInFigure( figure )
            // rotate the model and generate the requested data
            
            val promiseOfResult = Akka.future {
              def f( x: List[Int], y: Seq[Tuple3[Int, Int, Int]] ) {
                if ( x.length / 3 != y.length ) System.err.println( "Size doesn't match! %d (S) != %d (C)".format(x.length/3,y.length) )
                else
                  y.zipWithIndex.foreach {
                    case ( e, i ) => {
                      val client = ( x( i*3 ), x( i*3 + 1 ), x( i*3 + 2 ) )
                      if ( e != client )
                        System.err.println( "ELEMTNS don't match: %s (S) <-> %s (C)".format( e, client ) )
                    }
                  }
              }
              f( clientCoord, coordinates )
            }

            val result: Array[Byte] =
              coordinates.map( DataStore.load ).toArray
            println( "Calculated %d points.".format( coordinates.size ) )
            output.push( binHandle ++ result )
          case _ =>
            output.push( binHandle )
        }

      }
    } )

    ( input, output )
  }

  def model( modelType: String ) = Action {
    ModelStore( modelType ) match {
      case Some( m ) =>
        Ok( toJson( m.vertices ) )
      case _ =>
        NotFound( "Model not available." )
    }
  }
  def polygons( modelType: String ) = Action {
    ModelStore( modelType ) match {
      case Some( m ) =>
        Ok( toJson( m.polygons ) )
      case _ =>
        NotFound( "Model not available." )
    }
  }
}