// Proving type safety of the Simply Typed Lambda-Calculus in Dafny
// adapted from Coq (http://www.cis.upenn.edu/~bcpierce/sf/Stlc.html)

// Utilities
datatype option<A> = None | Some(get: A);

// Syntax

// Types
datatype ty = TBool | TArrow(paramT: ty, bodyT: ty);

// Terms
datatype tm = tvar(id: int) | tapp(f: tm, arg: tm) | tabs(x: int, T: ty, body: tm) |
              ttrue | tfalse | tif(c: tm, a: tm, b: tm);


// Operational Semantics

// Values
function value(t: tm): bool
{
  t.tabs? || t.ttrue? || t.tfalse?
}

// Free Variables and Substitution
function fv(t: tm): set<int>
{
  match t
  case tvar(id) => {id}
  case tapp(f, arg) => fv(f)+fv(arg)
  case tabs(x, T, body) => fv(body)-{x}
  case tif(c, a, b) => fv(a)+fv(b)+fv(c)
  case ttrue => {}
  case tfalse => {}
}
function subst(x: int, s: tm, t: tm): tm
{
  match t
  case tvar(x') => if x==x' then s else t
  case tabs(x', T, t1) => tabs(x', T, if x==x' then t1 else subst(x, s, t1))
  case tapp(t1, t2) => tapp(subst(x, s, t1), subst(x, s, t2))
  case ttrue => ttrue
  case tfalse => tfalse
  case tif(t1, t2, t3) => tif(subst(x, s, t1), subst(x, s, t2), subst(x, s, t3))
}

// Reduction
function step(t: tm): option<tm>
{
  /* AppAbs */     if (t.tapp? && t.f.tabs? && value(t.arg)) then Some(subst(t.f.x, t.arg, t.f.body))
  /* App1 */       else if (t.tapp? && step(t.f).Some?) then Some(tapp(step(t.f).get, t.arg))
  /* App2 */       else if (t.tapp? && step(t.arg).Some?) then Some(tapp(t.f, step(t.arg).get))
  /* IfTrue */     else if (t.tif? && t.c == ttrue) then Some(t.a)
  /* IfFalse */    else if (t.tif? && t.c == tfalse) then Some(t.b)
  /* If */         else if (t.tif? && step(t.c).Some?) then Some(tif(step(t.c).get, t.a, t.b))
                   else None
}

// The term t reduces to the term t' in n or less number of steps.
function reduces_to(t: tm, t': tm, n: nat): bool
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


// Typing

// A context is a partial map from variable names to types.
function find(c: map<int,ty>, x: int): option<ty>
  ensures (x in c)   ==> find(c, x) == Some(c[x]);
  ensures (x !in c) <==> find(c, x) == None;
{
  if (x in c) then Some(c[x]) else None
}
function extend(x: int, T: ty, c: map<int,ty>): map<int,ty>
  ensures extend(x, T, c)==c[x:=T];
  ensures find(extend(x, T, c), x) == Some(T);
{
  c[x:=T]
}

// Typing Relation
function has_type(c: map<int,ty>, t: tm): option<ty>
  decreases t;
{
  match t
  /* Var */        case tvar(id) => find(c, id)
  /* Abs */        case tabs(x, T, body) =>
                     var ty_body := has_type(extend(x, T, c), body);
                     if (ty_body.Some?) then Some(TArrow(T, ty_body.get)) else None
  /* App */        case tapp(f, arg) =>
                     var ty_f := has_type(c, f);
                     var ty_arg := has_type(c, arg);
                     if (ty_f.Some? && ty_arg.Some? && ty_f.get.TArrow? && ty_f.get.paramT == ty_arg.get)
                     then Some(ty_f.get.bodyT)
                     else None
 /* True */        case ttrue => Some(TBool)
 /* False */       case tfalse => Some(TBool)
 /* If */          case tif(cond, a, b) =>
                     var ty_c := has_type(c, cond);
                     var ty_a := has_type(c, a);
                     var ty_b := has_type(c, b);
                     if (ty_c.Some? && ty_a.Some? && ty_b.Some? && ty_c.get == TBool && ty_a.get == ty_b.get)
                     then ty_a
                     else None
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
  var c:= extend(0, S, map[]);
  assert has_type(c, tapp(tvar(0), tvar(0))) == None;
}


// Type-Safety Properties

// We're only interested in closed terms.
function closed(t: tm): bool
{
  forall x :: x !in fv(t)
}

// Progress
ghost method theorem_progress(t: tm)
  requires has_type(map[], t).Some?;
  ensures value(t) || step(t).Some?;
{
}

// Towards the substitution lemma

ghost method {:induction t} lemma_free_in_context(c: map<int,ty>, x: int, t: tm)
  requires x in fv(t);
  requires has_type(c, t).Some?;
  ensures find(c, x).Some?;
  decreases t;
{
  if (t.tabs?) {
    assert t.x != x;
    lemma_free_in_context(extend(t.x, t.T, c), x, t.body);
  }
}

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

ghost method lemma_context_invariance(c: map<int,ty>, c': map<int,ty>, t: tm)
  requires has_type(c, t).Some?;
  requires forall x: int :: x in fv(t) ==> find(c, x) == find(c', x);
  ensures has_type(c, t) == has_type(c', t);
  decreases t;
{
}

ghost method lemma_substitution_preserves_typing(c: map<int,ty>, x: int, t': tm, t: tm)
  requires has_type(map[], t').Some?;
  requires has_type(extend(x, has_type(map[], t').get, c), t).Some?;
  ensures has_type(c, subst(x, t', t)) == has_type(extend(x, has_type(map[], t').get, c), t);
  decreases t;
{
  var T' := has_type(map[], t').get;
  var c' := extend(x, T', c);
  var T  := has_type(c', t).get;

  if (t.tvar?) {
    if (t.id==x) {
      assert T == T';
      corollary_typable_empty__closed(t');
      lemma_context_invariance(map[], c, t');
    }
  }
  if (t.tabs?) {
    if (t.x==x) {
      lemma_context_invariance(c', c, t);
    } else {
      var cx  := extend(t.x, t.T, c);
      var c'x := extend(x, T', cx);
      var cx' := extend(t.x, t.T, c');
      lemma_context_invariance(cx', c'x, t.body);
      lemma_substitution_preserves_typing(cx, x, t', t.body);
    }
  }
}


// Preservation
ghost method theorem_preservation(t: tm)
  requires has_type(map[], t).Some?;
  requires step(t).Some?;
  ensures has_type(map[], step(t).get) == has_type(map[], t);
{
  if (t.tapp? && step(t.f).None? && step(t.arg).None?) {
    lemma_substitution_preserves_typing(map[], t.f.x, t.arg, t.f.body);
  }
}


// Type Soundness

function normal_form(t: tm): bool
{
  step(t).None?
}

function stuck(t: tm): bool
{
  normal_form(t) && !value(t)
}

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