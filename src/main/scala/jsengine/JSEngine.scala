package org.nlogo.tortoise.jsengine

import
  nashorn.{ Nashorn => NNashorn },
  spidermonkey.{ SpiderMonkey => NSpiderMonkey },
  v8.{ V8 => NV8 }


trait JSEngine {
  type T
  def engine: T
  def eval(js: String): String
}

trait JSEngineCompanion {

  protected type T <: JSEngine

  def cleanSlate: T
  def version:    String

  def name:                  String = this.getClass.getSimpleName.init
  def freshEval(js: String): String = cleanSlate.eval(js)

}

object JSEngine {

  implicit class NashornEngine(override val engine: NNashorn) extends JSEngine {
    override type T = NNashorn
    override def eval(js: String): String = engine.eval(js).toString
  }

  implicit class V8Engine(override val engine: NV8) extends JSEngine {
    override type T = NV8
    override def eval(js: String): String = engine.eval(js).toString
  }

  implicit class SpiderMonkeyEngine(override val engine: NSpiderMonkey) extends JSEngine {
    override type T = NSpiderMonkey
    override def eval(js: String): String = engine.eval(js).toString
  }

  object Nashorn extends JSEngineCompanion {
    override protected type T = NashornEngine
    override def cleanSlate = new NNashorn
    override def version    = cleanSlate.engine.versionNumber
  }

  object SpiderMonkey extends JSEngineCompanion {
    override protected type T = SpiderMonkeyEngine
    override def cleanSlate = new NSpiderMonkey
    override def version    = cleanSlate.engine.versionNumber
  }

  object V8 extends JSEngineCompanion {
    override protected type T = V8Engine
    override def cleanSlate = new NV8
    override def version    = cleanSlate.engine.versionNumber
  }

}

