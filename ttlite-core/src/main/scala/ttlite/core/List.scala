package ttlite.core

import ttlite.common._

trait ListAST extends CoreAST {
  case class PiList(A: Term) extends Term
  case class PiNil(et: Term) extends Term
  case class PiCons(et: Term, head: Term, tail: Term) extends Term
  case class PiListElim(et: Term, motive: Term, nilCase: Term, consCase: Term, l: Term) extends Term

  case class VPiList(A: Value) extends Value
  case class VPiNil(et: Value) extends Value
  case class VPiCons(et: Value, head: Value, tail: Value) extends Value
  case class NPiListElim(et: Value, motive: Value, nilCase: Value, consCase: Value, l: Neutral) extends Neutral
}

trait ListMetaSyntax extends CoreMetaSyntax with ListAST {
  override def fromM(m: MTerm): Term = m match {
    case MVar(Global("List")) @@ a =>
      PiList(fromM(a))
    case MVar(Global("Nil")) @@ a =>
      PiNil(fromM(a))
    case MVar(Global("Cons")) @@ a @@ h @@ t =>
      PiCons(fromM(a), fromM(h), fromM(t))
    case MVar(Global("elim")) @@ (MVar(Global("List")) @@ a) @@ m @@ cN @@ cC @@ n =>
      PiListElim(PiList(fromM(a)), fromM(m), fromM(cN), fromM(cC), fromM(n))
    case _ => super.fromM(m)
  }
}

trait ListPrinter extends FunPrinter with ListAST {
  override def print(p: Int, ii: Int, t: Term): Doc = t match {
    case PiList(a) =>
      print(p, ii, 'List @@ a)
    case PiNil(a) =>
      print(p, ii, 'Nil @@ a)
    case PiCons(a, x, xs) =>
      print(p, ii, 'Cons @@ a @@ x @@ xs)
    case PiListElim(a, m, mn, mc, xs) =>
      print(p, ii, 'elim @@ a @@ m @@ mn @@ mc @@ xs)
    case _ =>
      super.print(p, ii, t)
  }
}

trait ListPrinterAgda extends FunPrinterAgda with ListAST {
  override def printA(p: Int, ii: Int, t: Term): Doc = t match {
    case PiList(a) =>
      printA(p, ii, 'List @@ a)
    case PiNil(PiList(a)) =>
      printA(p, ii, 'nil @@ a)
    case PiCons(PiList(a), x, xs) =>
      printA(p, ii, 'cons @@ a @@ x @@ xs)
    case PiListElim(PiList(a), m, mn, mc, xs) =>
      printA(p, ii, 'elimList @@ a @@ m @@ mn @@ mc @@ xs)
    case _ =>
      super.printA(p, ii, t)
  }
}


trait ListEval extends FunEval with ListAST {
  override def eval(t: Term, ctx: Context[Value], bound: Env): Value = t match {
    case PiList(a) =>
      VPiList(eval(a, ctx, bound))
    case PiNil(et) =>
      VPiNil(eval(et, ctx, bound))
    case PiCons(et, head, tail) =>
      VPiCons(eval(et, ctx, bound), eval(head, ctx, bound), eval(tail, ctx, bound))
    case PiListElim(et, m, nilCase, consCase, ls) =>
      val etVal = eval(et, ctx, bound)
      val mVal = eval(m, ctx, bound)
      val nilCaseVal = eval(nilCase, ctx, bound)
      val consCaseVal = eval(consCase, ctx, bound)
      val listVal = eval(ls, ctx, bound)
      listElim(etVal, mVal, nilCaseVal, consCaseVal, listVal)
    case _ =>
      super.eval(t, ctx, bound)
  }

  def listElim(etVal: Value, mVal: Value, nilCaseVal: Value, consCaseVal: Value, listVal: Value): Value = listVal match {
    case VPiNil(_) =>
      nilCaseVal
    case VPiCons(_, head, tail) =>
      consCaseVal @@ head @@ tail @@ listElim(etVal, mVal, nilCaseVal, consCaseVal, tail)
    case VNeutral(n) =>
      VNeutral(NPiListElim(etVal, mVal, nilCaseVal, consCaseVal, n))
  }
}

trait ListCheck extends FunCheck with ListAST {
  override def iType(i: Int, path : Path, ctx: Context[Value], t: Term): Value = t match {
    case PiList(a) =>
      val aType = iType(i, path/(2, 2), ctx, a)
      val j = checkUniverse(i, aType, path/(2, 2))
      VUniverse(j)
    case PiNil(et) =>
      val eType = iType(i, path/(2, 2), ctx, et)
      checkUniverse(i, eType, path/(2, 2))

      val VPiList(aVal) = eval(et, ctx, List())
      VPiList(aVal)
    case PiCons(et, head, tail) =>
      val eType = iType(i, path/(2, 4), ctx, et)
      checkUniverse(i, eType, path/(2, 4))

      val VPiList(aVal) = eval(et, ctx, List())

      val hType = iType(i, path/(3, 4), ctx, head)
      checkEqual(i, hType, aVal, path/(3, 4))

      val tType = iType(i, path/(4, 4), ctx, tail)
      checkEqual(i, tType, VPiList(aVal), path/(4, 4))

      VPiList(aVal)
    case PiListElim(et, m, nilCase, consCase, xs) =>
      val eType = iType(i, path/(2, 6), ctx, et)
      checkUniverse(i, eType, path/(2, 6))

      val etVal@VPiList(aVal) = eval(et, ctx, List())

      val mVal = eval(m, ctx, List())
      val xsVal = eval(xs, ctx, List())

      val mType = iType(i, path/(3, 6), ctx, m)
      checkEqual(i, mType, VPi(VPiList(aVal), {_ => VUniverse(-1)}), path/(3, 6))

      val nilCaseType = iType(i, path/(4, 6), ctx, nilCase)
      checkEqual(i, nilCaseType, mVal @@ VPiNil(etVal), path/(4, 6))

      val consCaseType = iType(i, path/(5, 6), ctx, consCase)
      checkEqual(i, consCaseType,
        VPi(aVal, {y => VPi(VPiList(aVal), {ys => VPi(mVal @@ ys, {_ => mVal @@ VPiCons(etVal, y, ys) }) }) }),
        path/(5, 6)
      )

      val xsType = iType(i, path/(6, 6), ctx, xs)
      checkEqual(i, xsType, VPiList(aVal), path/(6, 6))

      mVal @@ xsVal
    case _ =>
      super.iType(i, path, ctx, t)
  }

  override def iSubst(i: Int, r: Term, it: Term): Term = it match {
    case PiList(a) =>
      PiList(iSubst(i, r, a))
    case PiNil(a) =>
      PiNil(iSubst(i, r, a))
    case PiCons(a, head, tail) =>
      PiCons(iSubst(i, r, a), iSubst(i, r, head), iSubst(i, r, tail))
    case PiListElim(a, m, nilCase, consCase, xs) =>
      PiListElim(iSubst(i, r, a), iSubst(i, r, m), iSubst(i, r, nilCase), iSubst(i, r, consCase), iSubst(i, r, xs))
    case _ => super.iSubst(i, r, it)
  }
}

trait ListQuote extends CoreQuote with ListAST {
  override def quote(ii: Int, v: Value): Term = v match {
    case VPiList(a) =>
      PiList(quote(ii, a))
    case VPiNil(a) =>
      PiNil(quote(ii, a))
    case VPiCons(a, head, tail) =>
      PiCons(quote(ii, a), quote(ii, head), quote(ii, tail))
    case _ => super.quote(ii, v)
  }

  override def neutralQuote(ii: Int, n: Neutral): Term = n match {
    case NPiListElim(a, m, nilCase, consCase, vec) =>
      PiListElim(quote(ii, a), quote(ii, m), quote(ii, nilCase), quote(ii, consCase), neutralQuote(ii, vec))
    case _ => super.neutralQuote(ii, n)
  }
}

trait ListREPL
  extends CoreREPL
  with ListAST
  with ListMetaSyntax
  with ListPrinter
  with ListPrinterAgda
  with ListCheck
  with ListEval
  with ListQuote
