package brainflight.tools

import scala.math._
import brainflight.tools.geometry.Vector3D
import brainflight.tools.geometry.Polygon
import brainflight.tools.geometry.Figure
import brainflight.tools.geometry.Vector3D._

/**
 * Scalable Minds - Brainflight
 * User: tom
 * Date: 10/11/11
 * Time: 8:53 AM
 */

object Math {
  val RotationMatrixSize3D = 16

  val EPSILON = 1e-10

  def square(x: Int) = x * x

  def square(d: Double) = d * d

  val lnOf2 = scala.math.log(2) // natural log of 2
  
  def log2(x: Double): Double = scala.math.log(x) / lnOf2

}