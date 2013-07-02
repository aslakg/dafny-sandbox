// Proving type safety of a Simply Typed Lambda-Calculus in Dafny
// adapted from Coq (http://www.cis.upenn.edu/~bcpierce/sf/Stlc.html)

/// Utilities

// ... handy for partial functions
datatype option<A> = None | Some(get: A);

/// -----
/// Model
/// -----

/// Syntax

// Types
datatype ty =  TBool                  // (base type for boolean)
            |  TArrow(T1: ty, T2: ty) // T1 => T2
/*?
            |  TNat                   // (base type for naturals)
?*/
            ;

// Terms
datatype tm = tvar(id: int)                      // x                  (variable)
            | tapp(f: tm, arg: tm)               // t t                (application)
            | tabs(x: int, T: ty, body: tm)      // \x.t               (abstraction)
            | ttrue | tfalse                     // true, false        (boolean values)
            | tif(c: tm, a: tm, b: tm)           // if t then t else t (if expression)
/*?
            | tzero | tsucc(p: tm) | tprev(n: tm)//                    (naturals)
            | teq(n1: tm, n2: tm)                //                    (equality on naturals)
?*/

/// Operational Semantics

// Values
predicate value(t: tm)
{
  t.tabs? || t.ttrue? || t.tfalse?
/*?
  || peano(t)
?*/
}

/*?
predicate peano(t: tm)
{
  t.tzero? || (t.tsucc? && peano(t.p))
}
?*/

// Free Variables and Substitution

function fv(t: tm): set<int> //of free variables of t
{
  match t
  // interesting cases...
  case tvar(id) => {id}
  case tabs(x, T, body) => fv(body)-{x}//x is bound
  // congruent cases...
  case tapp(f, arg) => fv(f)+fv(arg)
  case tif(c, a, b) => fv(a)+fv(b)+fv(c)
  case ttrue => {}
  case tfalse => {}
/*?
  case tzero => {}
  case tsucc(p) => fv(p)
  case tprev(n) => fv(n)
  case teq(n1, n2) => fv(n1)+fv(n2)
?*/
}

function subst(x: int, s: tm, t: tm): tm //[x -> s]t
{
  match t
  // interesting cases...
  case tvar(x') => if x==x' then s else t
  // N.B. only capture-avoiding if s is closed...
  case tabs(x', T, t1) => tabs(x', T, if x==x' then t1 else subst(x, s, t1))
  // congruent cases...
  case tapp(t1, t2) => tapp(subst(x, s, t1), subst(x, s, t2))
  case ttrue => ttrue
  case tfalse => tfalse
  case tif(t1, t2, t3) => tif(subst(x, s, t1), subst(x, s, t2), subst(x, s, t3))
/*?
  case tzero => tzero
  case tsucc(p) => tsucc(subst(x, s, p))
  case tprev(n) => tprev(subst(x, s, n))
  case teq(n1, n2) => teq(subst(x, s, n1), subst(x, s, n2))
?*/
}

// Reduction
function step(t: tm): option<tm>
{
  /* AppAbs */     if (t.tapp? && t.f.tabs? && value(t.arg)) then
  Some(subst(t.f.x, t.arg, t.f.body))
  /* App1 */       else if (t.tapp? && step(t.f).Some?) then
  Some(tapp(step(t.f).get, t.arg))
  /* App2 */       else if (t.tapp? && value(t.f) && step(t.arg).Some?) then
  Some(tapp(t.f, step(t.arg).get))
  /* IfTrue */     else if (t.tif? && t.c == ttrue) then
  Some(t.a)
  /* IfFalse */    else if (t.tif? && t.c == tfalse) then
  Some(t.b)
  /* If */         else if (t.tif? && step(t.c).Some?) then
  Some(tif(step(t.c).get, t.a, t.b))
/*?
  /* Prev0 */
                   else if (t.tprev? && t.n.tzero?) then
  Some(tzero)
  /* PrevSucc */   else if (t.tprev? && peano(t.n) && t.n.tsucc?) then
  Some(t.n.p)
  /* Prev */       else if (t.tprev? && step(t.n).Some?) then
  Some(tprev(step(t.n).get))
  /* Succ */       else if (t.tsucc? && step(t.p).Some?) then
  Some(tsucc(step(t.p).get))
  /* EqTrue0 */    else if (t.teq? && t.n1.tzero? && t.n2.tzero?) then
  Some(ttrue)
  /* EqFalse1 */   else if (t.teq? && t.n1.tsucc? && peano(t.n1) && t.n2.tzero?) then
  Some(tfalse)
  /* EqFalse2 */   else if (t.teq? && t.n1.tzero? && t.n2.tsucc? && peano(t.n2)) then
  Some(tfalse)
  /* EqRec */      else if (t.teq? && t.n1.tsucc? && t.n2.tsucc? && peano(t.n1) && peano(t.n2)) then
  Some(teq(t.n1.p, t.n2.p))
  /* Eq1 */        else if (t.teq? && step(t.n1).Some?) then
  Some(teq(step(t.n1).get, t.n2))
  /* Eq2 */        else if (t.teq? && peano(t.n1) && step(t.n2).Some?) then
  Some(teq(t.n1, step(t.n2).get))
?*/
  else None
}

// Multistep reduction:
// The term t reduces to the term t' in n or less number of steps.
predicate reduces_to(t: tm, t': tm, n: nat)
  decreases n;
{
  t == t' || (n > 0 && step(t).Some? && reduces_to(step(t).get, t', n-1))
}

// Examples
ghost method lemma_step_example1(n: nat)
  requires n > 0;
  ensures reduces_to(tapp(tabs(0, TArrow(TBool, TBool), tvar(0)), tabs(0, TBool, tvar(0))),
                     tabs(0, TBool, tvar(0)), n);
{
}


/// Typing

// A context is a partial map from variable names to types.
function find(c: map<int,ty>, x: int): option<ty>
{
  if (x in c) then Some(c[x]) else None
}
function extend(x: int, T: ty, c: map<int,ty>): map<int,ty>
{
  c[x:=T]
}

// Typing Relation
function has_type(c: map<int,ty>, t: tm): option<ty>
  decreases t;
{
  match t
  /* Var */  case tvar(id) => find(c, id)
  /* Abs */  case tabs(x, T, body) =>
  var ty_body := has_type(extend(x, T, c), body);
                     if (ty_body.Some?) then
  Some(TArrow(T, ty_body.get))          else None
  /* App */  case tapp(f, arg) =>
  var ty_f   := has_type(c, f);
  var ty_arg := has_type(c, arg);
                     if (ty_f.Some? && ty_arg.Some?) then
  if ty_f.get.TArrow? && ty_f.get.T1 == ty_arg.get then
  Some(ty_f.get.T2)  else None else None
  /* True */  case ttrue => Some(TBool)
  /* False */ case tfalse => Some(TBool)
  /* If */    case tif(cond, a, b) =>
  var ty_c := has_type(c, cond);
  var ty_a := has_type(c, a);
  var ty_b := has_type(c, b);
                     if (ty_c.Some? && ty_a.Some? && ty_b.Some?) then
  if ty_c.get == TBool && ty_a.get == ty_b.get then
  ty_a
                     else None else None
/*?
  /* Zero */  case tzero => Some(TNat)
  /* Prev */  case tprev(n) =>
  var ty_n := has_type(c, n);
                     if (ty_n.Some?) then
  if ty_n.get == TNat then
  Some(TNat)         else None else None
  /* Succ */  case tsucc(p) =>
  var ty_p := has_type(c, p);
                     if (ty_p.Some?) then
  if ty_p.get == TNat then
  Some(TNat)         else None else None
  /* Eq */    case teq(n1, n2) =>
  var ty_n1 := has_type(c, n1);
  var ty_n2 := has_type(c, n2);
                      if (ty_n1.Some? && ty_n2.Some?) then
  if ty_n1.get == TNat && ty_n2.get == TNat then
  Some(TBool)         else None else None
 ?*/
}

// Examples

ghost method example_typing_1()
  ensures has_type(map[], tabs(0, TBool, tvar(0))) == Some(TArrow(TBool, TBool));
{
}

ghost method example_typing_2()
  ensures has_type(map[], tabs(0, TBool, tabs(1, TArrow(TBool, TBool), tapp(tvar(1), tapp(tvar(1), tvar(0)))))) ==
          Some(TArrow(TBool, TArrow(TArrow(TBool, TBool), TBool)));
{
  var c := extend(1, TArrow(TBool, TBool), extend(0, TBool, map[]));
  assert find(c, 0) == Some(TBool);
  assert has_type(c, tvar(0)) == Some(TBool);
  assert has_type(c, tvar(1)) == Some(TArrow(TBool, TBool));
  assert has_type(c, tapp(tvar(1), tapp(tvar(1), tvar(0)))) == Some(TBool);
}

ghost method nonexample_typing_1()
  ensures has_type(map[], tabs(0, TBool, tabs(1, TBool, tapp(tvar(0), tvar(1))))) == None;
{
  var c := extend(1, TBool, extend(0, TBool, map[]));
  assert find(c, 0) == Some(TBool);
  assert has_type(c, tapp(tvar(0), tvar(1))) == None;
}

ghost method nonexample_typing_3(S: ty, T: ty)
  ensures has_type(map[], tabs(0, S, tapp(tvar(0), tvar(0)))) != Some(T);
{
  var c := extend(0, S, map[]);
  assert has_type(c, tapp(tvar(0), tvar(0))) == None;
}

/*?
ghost method example_typing_nat()
  ensures has_type(map[], tabs(0, TNat, tprev(tvar(0)))) == Some(TArrow(TNat, TNat));
{
  var c := extend(0, TNat, map[]);
  assert has_type(c, tprev(tvar(0)))==Some(TNat);
}
?*/

/// -----------------------
/// Type-Safety Properties
/// -----------------------

// Progress:
// A well-typed term is either a value or it can step.
ghost method theorem_progress(t: tm)
  requires has_type(map[], t).Some?;
  ensures value(t) || step(t).Some?;
{
}

// Towards preservation and the substitution lemma

// If x is free in t and t is well-typed in some context,
// then this context must contain x.
ghost method {:induction c, t} lemma_free_in_context(c: map<int,ty>, x: int, t: tm)
  requires x in fv(t);
  requires has_type(c, t).Some?;
  ensures find(c, x).Some?;
  decreases t;
{
}

// A closed term does not contain any free variables.
// N.B. We're only interested in proving type soundness of closed terms.
predicate closed(t: tm)
{
  forall x :: x !in fv(t)
}

// If a term can be well-typed in an empty context,
// then it is closed.
ghost method corollary_typable_empty__closed(t: tm)
  requires has_type(map[], t).Some?;
  ensures closed(t);
{
  forall (x:int) ensures x !in fv(t);
  {
    if (x in fv(t)) {
      lemma_free_in_context(map[], x, t);
      assert false;
    }
  }
}

// If a term t is well-typed in context c,
//    and context c' agrees with c on all free variables of t,
// then the term t is well-typed in context c',
//      with the same type as in context c.
ghost method lemma_context_invariance(c: map<int,ty>, c': map<int,ty>, t: tm)
  requires has_type(c, t).Some?;
  requires forall x: int :: x in fv(t) ==> find(c, x) == find(c', x);
  ensures has_type(c, t) == has_type(c', t);
  decreases t;
{
}

// Substitution preserves typing:
// If  s has type S in an empty context,
// and t has type T in a context extended with x having type S,
// then [x -> s]t has type T as well.
ghost method lemma_substitution_preserves_typing(c: map<int,ty>, x: int, s: tm, t: tm)
  requires has_type(map[], s).Some?;
  requires has_type(extend(x, has_type(map[], s).get, c), t).Some?;
  ensures has_type(c, subst(x, s, t)) == has_type(extend(x, has_type(map[], s).get, c), t);
  decreases t;
{
  var S := has_type(map[], s).get;
  var cs := extend(x, S, c);
  var T  := has_type(cs, t).get;

  if (t.tvar?) {
    if (t.id==x) {
      assert T == S;
      corollary_typable_empty__closed(s);
      lemma_context_invariance(map[], c, s);
    }
  }
  if (t.tabs?) {
    if (t.x==x) {
      lemma_context_invariance(cs, c, t);
    } else {
      var cx  := extend(t.x, t.T, c);
      var csx := extend(x, S, cx);
      var cxs := extend(t.x, t.T, cs);
      lemma_context_invariance(cxs, csx, t.body);
      lemma_substitution_preserves_typing(cx, x, s, t.body);
    }
  }
}


// Preservation:
// A well-type term which steps preserves its type.
ghost method theorem_preservation(t: tm)
  requires has_type(map[], t).Some?;
  requires step(t).Some?;
  ensures has_type(map[], step(t).get) == has_type(map[], t);
{
  if (t.tapp? && value(t.f) && value(t.arg)) {
    lemma_substitution_preserves_typing(map[], t.f.x, t.arg, t.f.body);
  }
}

// A normal form cannot step.
predicate normal_form(t: tm)
{
  step(t).None?
}

// A stuck term is a normal form that is not a value.
predicate stuck(t: tm)
{
  normal_form(t) && !value(t)
}

// Type soundness:
// A well-typed term cannot be stuck.
ghost method corollary_soundness(t: tm, t': tm, T: ty, n: nat)
  requires has_type(map[], t) == Some(T);
  requires reduces_to(t, t', n);
  ensures !stuck(t');
  decreases n;
{
  theorem_progress(t);
  if (t != t') {
   theorem_preservation(t);
   corollary_soundness(step(t).get, t', T, n-1);
  }
}

/// QED