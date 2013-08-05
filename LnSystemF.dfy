datatype option<A> = None | Some(get: A);
function chain(a: option, b: option): option
{
  if (a.None?) then b else a
}

datatype pair<A,B> = P(fst: A, snd: B);

function not_in(s: set<int>, r: nat, sr: set<int>, so: set<int>): nat
  requires forall x :: x in sr ==> x<=r;
  requires s+sr==so;
  ensures not_in(s, r, sr, so) !in so;
{
  if (!exists x :: x in s) then r+1 else
  var x :| x in s;
  if (x<r) then not_in(s-{x}, r, sr+{x}, so) else not_in(s-{x}, x, sr+{x}, so)
}
function notin(s: set<int>): int
  ensures notin(s) !in s;
{
  not_in(s, 0, {}, s)
}

/// Definition of System F
/// https://github.com/plclub/metalib/blob/master/Fsub_LetSum_Definitions.v

datatype typ =
    typ_top
  | typ_bvar(n: nat)
  | typ_fvar(a: int)
  | typ_arrow(ty1: typ, ty2: typ)
  | typ_all(ty0: typ)

datatype exp =
    exp_bvar(n: nat)
  | exp_fvar(a: int)
  | exp_abs(ty: typ, e0: exp)
  | exp_app(f: exp, arg: exp)
  | exp_tabs(te0: exp)
  | exp_tapp(tf: exp, targ: typ)

function typ_size(T: typ): nat
{
  match T
  case typ_top => 1
  case typ_bvar(J) => 1
  case typ_fvar(X) => 1
  case typ_arrow(T1, T2) => 1+typ_size(T1)+typ_size(T2)
  case typ_all(T1) => 1+typ_size(T1)
}
function exp_size(e: exp): nat
{
  match e
  case exp_bvar(i) => 1
  case exp_fvar(x) => 1
  case exp_abs(V, e1) => 1+typ_size(V)+exp_size(e1)
  case exp_app(e1, e2) => 1+exp_size(e1)+exp_size(e2)
  case exp_tabs(e1) => 1+exp_size(e1)
  case exp_tapp(e1, V) => 1+exp_size(e1)+typ_size(V)
}

function open_tt_rec(K : nat, U : typ, T : typ): typ
  ensures U.typ_fvar? ==> typ_size(T)==typ_size(open_tt_rec(K, U, T));
  decreases T;
{
  match T
  case typ_top => typ_top
  case typ_bvar(J) => if K == J then U else typ_bvar(J)
  case typ_fvar(X) => typ_fvar(X)
  case typ_arrow(T1, T2) => typ_arrow(open_tt_rec(K, U, T1), open_tt_rec(K, U, T2))
  case typ_all(T1) => typ_all(open_tt_rec(K+1, U, T1))
}
function open_te_rec(K : nat, U : typ, e : exp): exp
  ensures U.typ_fvar? ==> exp_size(e)==exp_size(open_te_rec(K, U, e));
  decreases e;
{
  match e
  case exp_bvar(i) => exp_bvar(i)
  case exp_fvar(x) => exp_fvar(x)
  case exp_abs(V, e1) => exp_abs(open_tt_rec(K, U, V), open_te_rec(K, U, e1))
  case exp_app(e1, e2) => exp_app(open_te_rec(K, U, e1), open_te_rec(K, U, e2))
  case exp_tabs(e1) => exp_tabs(open_te_rec(K+1, U, e1))
  case exp_tapp(e1, V) => exp_tapp(open_te_rec(K, U, e1), open_tt_rec(K, U, V))
}
function open_ee_rec(k : nat, f : exp, e : exp): exp
  ensures f.exp_fvar? ==> exp_size(e)==exp_size(open_ee_rec(k, f, e));
  decreases e;
{
  match e
  case exp_bvar(i) => if k == i then f else exp_bvar(i)
  case exp_fvar(x) => exp_fvar(x)
  case exp_abs(V, e1) => exp_abs(V, open_ee_rec(k+1, f, e1))
  case exp_app(e1, e2) => exp_app(open_ee_rec(k, f, e1),open_ee_rec(k, f, e2))
  case exp_tabs(e1) => exp_tabs(open_ee_rec(k, f, e1))
  case exp_tapp(e1, V) => exp_tapp(open_ee_rec(k, f, e1), V)
}

function open_tt(T: typ, U: typ): typ { open_tt_rec(0, U, T) }
function open_te(e: exp, U: typ): exp { open_te_rec(0, U, e) }
function open_ee(e1: exp, e2: exp): exp { open_ee_rec(0, e2, e1) }

predicate typ_lc(T: typ)
  decreases typ_size(T);
{
  match T
  case typ_top => true
  case typ_bvar(J) => false
  case typ_fvar(X) => true
  case typ_arrow(T1, T2) => typ_lc(T1) && typ_lc(T2)
  case typ_all(T1) => exists L:set<int> :: forall X :: X !in L ==> typ_lc(open_tt(T1, typ_fvar(X)))
}
predicate exp_lc(e: exp)
  decreases exp_size(e);
{
  match e
  case exp_bvar(i) => false
  case exp_fvar(x) => true
  case exp_abs(V, e1) => typ_lc(V) && (exists L:set<int> :: forall x :: x !in L ==> exp_lc(open_ee(e1, exp_fvar(x))))
  case exp_app(e1, e2) => exp_lc(e1) && exp_lc(e2)
  case exp_tabs(e1) => exists L:set<int> :: forall X :: X !in L ==> exp_lc(open_te(e1, typ_fvar(X)))
  case exp_tapp(e1, V) => exp_lc(e1) && typ_lc(V)
}
predicate body_lc(e: exp)
{
  exists L:set<int> :: forall x :: x !in L ==> exp_lc(open_ee(e, exp_fvar(x)))
}

datatype binding =
    bd_typ(x: int, ty: typ)
  | bd_var(X: int)
datatype env = Env(bds: seq<binding>)
function env_plus_var(X: int, E: env): env
{
  Env([bd_var(X)]+E.bds)
}
predicate env_has_var(X: int, E: env)
{
  bd_var(X) in E.bds
}
function env_extend(x: int, T: typ, E: env): env
{
  Env([bd_typ(x, T)]+E.bds)
}
function env_lookup(x: int, E: env): option<typ>
{
  bds_lookup(x, E.bds)
}
function bds_lookup(x: int, bds: seq<binding>): option<typ>
{
  if |bds|==0 then None else chain(bd_lookup(x, bds[0]), bds_lookup(x, bds[1..]))
}
function bd_lookup(y: int, bd: binding): option<typ>
{
  match bd
  case bd_typ(x, T) => if x==y then Some(T) else None
  case bd_var(X) => None
}

predicate typ_wf(E: env, T: typ)
  decreases typ_size(T);
{
  match T
  case typ_top => true
  case typ_bvar(J) => false
  case typ_fvar(X) => env_has_var(X, E)
  case typ_arrow(T1, T2) => typ_wf(E, T1) && typ_wf(E, T2)
  case typ_all(T1) => exists L:set<int> :: forall X :: X !in L ==> typ_wf(env_plus_var(X, E), open_tt(T1, typ_fvar(X)))
}

function bd_dom(bd: binding): set<int>
{
  match bd
  case bd_typ(x, T) => {x}
  case bd_var(X) => {X}
}
function bds_dom(bds: seq<binding>): set<int>
{
  if |bds|==0 then {} else bd_dom(bds[0])+bds_dom(bds[1..])
}
predicate bds_wf(bds: seq<binding>)
  decreases bds, 0;
{
  |bds|==0 || (
    var bds' := bds[1..];
     bds_wf(bds') && bd_wf(bds[0], bds')
  )
}
predicate bd_wf(bd: binding, bds: seq<binding>)
  requires bds_wf(bds);
  decreases bds, 1;
{
  match bd
  case bd_typ(x, T) => typ_wf(Env(bds), T) && x !in bds_dom(bds)
  case bd_var(X) => X !in bds_dom(bds)
}
predicate env_wf(E: env)
{
  bds_wf(E.bds)
}

function typing(E: env, e: exp): option<typ>
  decreases exp_size(e);
{
  match e
  case exp_bvar(i) => None
  case exp_fvar(x) => if (env_wf(E)) then env_lookup(x, E) else None
  case exp_abs(V, e1) => if (exists L:set<int>, T1 :: forall x :: x !in L ==> typing(env_extend(x, V, E), open_ee(e1, exp_fvar(x))) == Some(T1)) then
    var L:set<int>, T1 :| forall x :: x !in L ==> typing(env_extend(x, V, E), open_ee(e1, exp_fvar(x))) == Some(T1);
    Some(typ_arrow(V, T1))
    else None
  case exp_app(e1, e2) => if (typing(E, e1).Some? && typing(E, e2).Some? && typing(E, e1).get.typ_arrow? && typing(E, e2).get==typing(E, e1).get.ty1) then
    Some(typing(E, e1).get.ty2)
    else None
  case exp_tabs(e1) => if (exists L:seq<int>, T1 :: forall X :: X !in L ==> typing(env_plus_var(X, E), open_te(e1, typ_fvar(X)))==Some(open_tt(T1, typ_fvar(X)))) then
    var L:seq<int>, T1 :| forall X :: X !in L ==> typing(env_plus_var(X, E), open_te(e1, typ_fvar(X)))==Some(open_tt(T1, typ_fvar(X)));
    Some(typ_all(T1))
    else None
  case exp_tapp(e1, T) => if (typing(E, e1).Some? && typing(E, e1).get.typ_all?) then
    Some(open_tt(typing(E, e1).get.ty0, T))
    else None
}

predicate value(e: exp)
{
  match e
  case exp_abs(V, e1) => exp_lc(e)
  case exp_tabs(e1) => exp_lc(e)
  case exp_bvar(i) => false
  case exp_fvar(x) => false
  case exp_app(e1, e2) => false
  case exp_tapp(e1, V) => false
}

function red(e: exp): option<exp>
{
  // red_app_1
  if (e.exp_app? && exp_lc(e.arg) && red(e.f).Some?) then
    Some(exp_app(red(e.f).get, e.arg))
  // red_app_2
  else if (e.exp_app? && value(e.f) && red(e.arg).Some?) then
    Some(exp_app(e.f, red(e.arg).get))
  // red_tapp
  else if (e.exp_tapp? && typ_lc(e.targ) && red(e.tf).Some?) then
    Some(exp_tapp(red(e.tf).get, e.targ))
  // red_abs
  else if (e.exp_app? && value(e.f) && value(e.arg) && e.f.exp_abs?) then
    Some(open_ee(e.f.e0, e.arg))
  // red_tabs
  else if (e.exp_tapp? && value(e.tf) && typ_lc(e.targ) && e.tf.exp_tabs?) then
    Some(open_te(e.tf.te0, e.targ))
  else None
}

/// Infrastructure
/// https://github.com/plclub/metalib/blob/master/Fsub_LetSum_Infrastructure.v

function fv_tt(T: typ): set<int>
{
  match T
  case typ_top => {}
  case typ_bvar(J) => {}
  case typ_fvar(X) => {X}
  case typ_arrow(T1, T2) => fv_tt(T1) + fv_tt(T2)
  case typ_all(T1) => fv_tt(T1)
}

function fv_te(e: exp): set<int>
{
  match e
  case exp_bvar(i) => {}
  case exp_fvar(x) => {}
  case exp_abs(V, e1)  => fv_tt(V) + fv_te(e1)
  case exp_app(e1, e2) => fv_te(e1) + fv_te(e2)
  case exp_tabs(e1) => fv_te(e1)
  case exp_tapp(e1, V) => fv_tt(V) + fv_te(e1)
}

function fv_ee(e: exp): set<int>
{
  match e
  case exp_bvar(i) => {}
  case exp_fvar(x) => {x}
  case exp_abs(V, e1) => fv_ee(e1)
  case exp_app(e1, e2) => fv_ee(e1) + fv_ee(e2)
  case exp_tabs(e1) => fv_ee(e1)
  case exp_tapp(e1, V) => fv_ee(e1)
}

function subst_tt (Z: int, U: typ, T : typ): typ
  decreases T;
{
  match T
  case typ_top => typ_top
  case typ_bvar(J) => typ_bvar(J)
  case typ_fvar(X) => if X == Z then U else T
  case typ_arrow(T1, T2) => typ_arrow(subst_tt(Z, U, T1), subst_tt(Z, U, T2))
  case typ_all(T1) => typ_all(subst_tt(Z, U, T1))
}
function subst_te(Z: int, U: typ, e : exp): exp
  decreases e;
{
  match e
  case exp_bvar(i) => exp_bvar(i)
  case exp_fvar(x) => exp_fvar(x)
  case exp_abs(V, e1) => exp_abs(subst_tt(Z, U, V),subst_te(Z, U, e1))
  case exp_app(e1, e2) => exp_app(subst_te(Z, U, e1), subst_te(Z, U, e2))
  case exp_tabs(e1) => exp_tabs(subst_te(Z, U, e1))
  case exp_tapp(e1, V) => exp_tapp(subst_te(Z, U, e1), subst_tt(Z, U, V))
}
function subst_ee(z: int, u: exp, e: exp): exp
  decreases e;
{
  match e
  case exp_bvar(i) => exp_bvar(i)
  case exp_fvar(x) => if x == z then u else e
  case exp_abs(V, e1) => exp_abs(V, subst_ee(z, u, e1))
  case exp_app(e1, e2) => exp_app(subst_ee(z, u, e1), subst_ee(z, u, e2))
  case exp_tabs(e1) => exp_tabs(subst_ee(z, u, e1))
  case exp_tapp(e1, V) => exp_tapp(subst_ee(z, u, e1), V)
}

ghost method {:induction T, j, i} lemma_open_tt_rec_type_aux(T: typ, j: nat, V: typ, i: nat, U: typ)
  requires i != j;
  requires open_tt_rec(j, V, T) == open_tt_rec(i, U, open_tt_rec(j, V, T));
  ensures T == open_tt_rec(i, U, T);
{
}

ghost method lemma_open_tt_rec_type(T: typ, U: typ, k: nat)
  requires typ_lc(T);
  ensures T == open_tt_rec(k, U, T);
  decreases typ_size(T);
{
  if (T.typ_all?) {
    var L:set<int> :| forall X :: X !in L ==> typ_lc(open_tt(T.ty0, typ_fvar(X)));
    var X := notin(L);
    lemma_open_tt_rec_type(open_tt(T.ty0, typ_fvar(X)), U, k+1);
    lemma_open_tt_rec_type_aux(T.ty0, 0, typ_fvar(X), k+1, U);
  }
}

ghost method lemma_subst_tt_fresh(Z: int, U: typ, T: typ)
  requires Z !in fv_tt(T);
  ensures T == subst_tt(Z, U, T);
{
}

ghost method lemma_subst_tt_open_tt_rec(T1: typ, T2: typ, X: int, P: typ, k: nat)
  requires typ_lc(P);
  ensures subst_tt(X, P, open_tt_rec(k, T2, T1))
       == open_tt_rec(k, subst_tt(X, P, T2), subst_tt(X, P, T1));
{
  if (T1.typ_fvar? && T1.a==X) {
    lemma_open_tt_rec_type(P, subst_tt(X, P, T2), k);
  }
}

ghost method lemma_subst_tt_open_tt(T1: typ, T2: typ, X: int, P: typ)
  requires typ_lc(P);
  ensures subst_tt(X, P, open_tt(T1, T2)) == open_tt(subst_tt(X, P, T1), subst_tt(X, P, T2));
{
  lemma_subst_tt_open_tt_rec(T1, T2, X, P, 0);
}

ghost method lemma_subst_tt_open_tt_var(X: int, Y: int, P: typ, T: typ)
  requires Y != X;
  requires typ_lc(P);
  ensures open_tt(subst_tt(X, P, T), typ_fvar(Y)) == subst_tt(X, P, open_tt(T, typ_fvar(Y)));
{
  lemma_subst_tt_open_tt(T, typ_fvar(Y), X, P);
}

ghost method lemma_subst_tt_intro_rec(X: int, T2: typ, U: typ, k: nat)
  requires X !in fv_tt(T2);
  ensures open_tt_rec(k, U, T2) == subst_tt(X, U, open_tt_rec(k, typ_fvar(X), T2));
{
}

ghost method lemma_subst_tt_intro(X: int, T2: typ, U: typ)
  requires X !in fv_tt(T2);
  ensures open_tt(T2, U) == subst_tt(X, U, open_tt(T2, typ_fvar(X)));
{
  lemma_subst_tt_intro_rec(X, T2, U, 0);
}

ghost method {:induction e, j, i} lemma_open_te_rec_expr_aux(e: exp, j: nat, u: exp, i: nat, P: typ)
  requires open_ee_rec(j, u, e) == open_te_rec(i, P, open_ee_rec(j, u, e));
  ensures e == open_te_rec(i, P, e);
{
}

ghost method {:induction e, j, i} lemma_open_te_rec_type_aux(e: exp, j: nat, Q: typ, i: nat, P: typ)
  requires i != j;
  requires open_te_rec(j, Q, e) == open_te_rec(i, P, open_te_rec(j, Q, e));
  ensures e == open_te_rec(i, P, e);
{
  forall (V | i !=j && open_tt_rec(j, Q, V) == open_tt_rec(i, P, open_tt_rec(j, Q, V)))
  ensures V == open_tt_rec(i, P, V);
  {
    lemma_open_tt_rec_type_aux(V, j, Q, i, P);
  }
}

ghost method lemma_open_te_rec_expr(e: exp, U: typ, k: nat)
  requires exp_lc(e);
  ensures e == open_te_rec(k, U, e);
  decreases exp_size(e);
{
  forall (V | typ_lc(V))
  ensures V == open_tt_rec(k, U, V);
  {
    lemma_open_tt_rec_type(V, U, k);
  }
  if (e.exp_abs?) {
    var L:set<int> :| forall x :: x !in L ==> exp_lc(open_ee(e.e0, exp_fvar(x)));
    var x := notin(L);
    lemma_open_te_rec_expr(open_ee(e.e0, exp_fvar(x)), U, k);
    lemma_open_te_rec_expr_aux(e.e0, 0, exp_fvar(x), k, U);
  } else if (e.exp_tabs?) {
    var L:set<int> :| forall X :: X !in L ==> exp_lc(open_te(e.te0, typ_fvar(X)));
    var X := notin(L);
    lemma_open_te_rec_type_aux(e.te0, 0, typ_fvar(X), k+1, U);
  }
}

ghost method lemma_subst_te_fresh(X: int, U: typ, e: exp)
  requires X !in fv_te(e);
  ensures e == subst_te(X, U, e);
{
  forall (T | X !in fv_tt(T))
  ensures T == subst_tt(X, U, T);
  {
    lemma_subst_tt_fresh(X, U, T);
  }
}

ghost method lemma_subst_te_open_te_rec(e: exp, T: typ, X: int, U: typ, k: nat)
  requires typ_lc(U);
  ensures subst_te(X, U, open_te_rec(k, T, e))
       == open_te_rec(k, subst_tt(X, U, T), subst_te(X, U, e));
{
  forall (V | V<e)
  ensures subst_tt(X, U, open_tt_rec(k, T, V))
       == open_tt_rec(k, subst_tt(X, U, T), subst_tt(X, U, V));
  {
    lemma_subst_tt_open_tt_rec(V, T, X, U, k);
  }
}

ghost method lemma_subst_te_open_te(e: exp, T: typ, X: int, U: typ)
  requires typ_lc(U);
  ensures subst_te(X, U, open_te(e, T)) == open_te(subst_te(X, U, e), subst_tt(X, U, T));
{
  lemma_subst_te_open_te_rec(e, T, X, U, 0);
}

ghost method lemma_subst_te_open_te_var(X: int, Y: int, U: typ, e: exp)
  requires Y != X;
  requires typ_lc(U);
  ensures open_te(subst_te(X, U, e), typ_fvar(Y)) == subst_te(X, U, open_te(e, typ_fvar(Y)));
{
  lemma_subst_te_open_te(e, typ_fvar(Y), X, U);
}

ghost method lemma_subst_te_intro_rec(X: int, e: exp, U: typ, k: nat)
  requires X !in fv_te(e);
  ensures open_te_rec(k, U, e) == subst_te(X, U, open_te_rec(k, typ_fvar(X), e));
{
  forall (V | V<e && X !in fv_tt(V))
  ensures open_tt_rec(k, U, V) == subst_tt(X, U, open_tt_rec(k, typ_fvar(X), V));
  {
    lemma_subst_tt_intro_rec(X, V, U, k);
  }
}

ghost method lemma_subst_te_intro(X: int, e: exp, U: typ)
  requires X !in fv_te(e);
  ensures open_te(e, U) == subst_te(X, U, open_te(e, typ_fvar(X)));
{
  lemma_subst_te_intro_rec(X, e, U, 0);
}

ghost method {:induction e, j, i} lemma_open_ee_rec_expr_aux(e: exp, j: nat, v: exp, u: exp, i: nat)
  requires i != j;
  requires open_ee_rec(j, v, e) == open_ee_rec(i, u, open_ee_rec(j, v, e));
  ensures e == open_ee_rec(i, u, e);
{
}

ghost method {:induction e, j, i} lemma_open_ee_rec_type_aux(e: exp, j: nat, V: typ, u: exp, i: nat)
  requires open_te_rec(j, V, e) == open_ee_rec(i, u, open_te_rec(j, V, e));
  ensures e == open_ee_rec(i, u, e);
{
}

ghost method lemma_open_ee_rec_expr(u: exp, e: exp, k: nat)
  requires exp_lc(e);
  ensures e == open_ee_rec(k, u, e);
  decreases exp_size(e);
{
  if (e.exp_abs?) {
    var L:set<int> :| forall x :: x !in L ==> exp_lc(open_ee(e.e0, exp_fvar(x)));
    var x := notin(L);
    lemma_open_ee_rec_expr(u, open_ee(e.e0, exp_fvar(x)), k);
    lemma_open_ee_rec_expr_aux(e.e0, 0, exp_fvar(x), u, k+1);
  } else if (e.exp_tabs?) {
    var L:set<int> :| forall X :: X !in L ==> exp_lc(open_te(e.te0, typ_fvar(X)));
    var X := notin(L);
    lemma_open_ee_rec_type_aux(e.te0, 0, typ_fvar(X), u, k);
  }
}

ghost method lemma_subst_ee_fresh(x: int, u: exp, e: exp)
  requires x !in fv_ee(e);
  ensures e == subst_ee(x, u, e);
{
}

ghost method lemma_subst_ee_open_ee_rec(e1: exp, e2: exp, x: int, u: exp, k: nat)
  requires exp_lc(u);
  ensures subst_ee(x, u, open_ee_rec(k, e2, e1))
       == open_ee_rec(k, subst_ee(x, u, e2), subst_ee(x, u, e1));
{
  if (e1.exp_fvar? && e1.a==x) {
    lemma_open_ee_rec_expr(subst_ee(x, u, e2), u, k);
  }
}

ghost method lemma_subst_ee_open_ee(e1: exp, e2: exp, x: int, u: exp)
  requires exp_lc(u);
  ensures subst_ee(x, u, open_ee(e1, e2))
       == open_ee(subst_ee(x, u, e1), subst_ee(x, u, e2));
{
  lemma_subst_ee_open_ee_rec(e1, e2, x, u, 0);
}

ghost method lemma_subst_ee_open_ee_var(x: int, y: int, u: exp, e: exp)
  requires y != x;
  requires exp_lc(u);
  ensures open_ee(subst_ee(x, u, e), exp_fvar(y)) == subst_ee(x, u, open_ee(e, exp_fvar(y)));
{
  lemma_subst_ee_open_ee(e, exp_fvar(y), x, u);
}

ghost method lemma_subst_te_open_ee_rec(e1: exp, e2: exp, Z: int, P: typ, k: nat)
  ensures subst_te(Z, P, open_ee_rec(k, e2, e1))
       == open_ee_rec(k, subst_te(Z, P, e2), subst_te(Z, P, e1));
{
}

ghost method lemma_subst_te_open_ee(e1: exp, e2: exp, Z: int, P: typ)
  ensures subst_te(Z, P, open_ee(e1, e2)) == open_ee(subst_te(Z, P, e1), subst_te(Z, P, e2));
{
  lemma_subst_te_open_ee_rec(e1, e2, Z, P, 0);
}

ghost method lemma_subst_te_open_ee_var(Z: int, x: int, P: typ, e: exp)
  ensures open_ee(subst_te(Z, P, e), exp_fvar(x)) == subst_te(Z, P, open_ee(e, exp_fvar(x)));
{
  lemma_subst_te_open_ee(e, exp_fvar(x), Z, P);
}

ghost method lemma_subst_ee_open_te_rec(e: exp, P: typ, z: int, u: exp, k: nat)
  requires exp_lc(u);
  ensures subst_ee(z, u, open_te_rec(k, P, e)) == open_te_rec(k, P, subst_ee(z, u, e));
{
  if (e.exp_fvar? && e.a==z) {
    lemma_open_te_rec_expr(u, P, k);
  }
}

ghost method lemma_subst_ee_open_te(e: exp, P: typ, z: int, u: exp)
  requires exp_lc(u);
  ensures subst_ee(z, u ,open_te(e, P)) == open_te(subst_ee(z, u, e), P);
{
  lemma_subst_ee_open_te_rec(e, P, z, u, 0);
}

ghost method lemma_subst_ee_open_te_var(z: int, X: int, u: exp, e: exp)
  requires exp_lc(u);
  ensures open_te(subst_ee(z, u, e), typ_fvar(X)) == subst_ee(z, u, open_te(e, typ_fvar(X)));
{
  lemma_subst_ee_open_te(e, typ_fvar(X), z, u);
}

ghost method lemma_subst_ee_intro_rec(x: int, e: exp, u: exp, k: nat)
  requires x !in fv_ee(e);
  ensures open_ee_rec(k, u, e) == subst_ee(x, u, open_ee_rec(k, exp_fvar(x), e));
{
}

ghost method lemma_subst_ee_intro(x: int, e: exp, u: exp)
  requires x !in fv_ee(e);
  ensures open_ee(e, u) == subst_ee(x, u, open_ee(e, exp_fvar(x)));
{
  lemma_subst_ee_intro_rec(x, e, u, 0);
}

ghost method lemma_subst_tt_type(Z: int, P: typ, T: typ)
  requires typ_lc(T);
  requires typ_lc(P);
  ensures typ_lc(subst_tt(Z, P, T));
  decreases typ_size(T);
{
  if (T.typ_all?) {
    var L:set<int> :| forall X :: X !in L ==> typ_lc(open_tt(T.ty0, typ_fvar(X)));
    var L' := L+{Z};
    forall (X | X !in L')
    ensures typ_lc(open_tt(subst_tt(Z, P, T.ty0), typ_fvar(X)));
    {
      lemma_subst_tt_type(Z, P, open_tt(T.ty0, typ_fvar(X)));
      lemma_subst_tt_open_tt_var(Z, X, P, T.ty0);
    }
  }
}

ghost method lemma_subst_te_expr(Z: int, P: typ, e: exp)
  requires exp_lc(e);
  requires typ_lc(P);
  ensures exp_lc(subst_te(Z, P, e));
  decreases exp_size(e);
{
  forall (V | V<e && typ_lc(V))
  ensures typ_lc(subst_tt(Z, P, V));
  {
    lemma_subst_tt_type(Z, P, V);
  }
  if (e.exp_abs?) {
    var L:set<int> :| forall x :: x !in L ==> exp_lc(open_ee(e.e0, exp_fvar(x)));
    forall (x | x !in L)
    ensures exp_lc(open_ee(subst_te(Z, P, e.e0), exp_fvar(x)));
    {
      lemma_subst_te_expr(Z, P, open_ee(e.e0, exp_fvar(x)));
      lemma_subst_te_open_ee_var(Z, x, P, e.e0);
    }
  } else if (e.exp_tabs?) {
    var L:set<int> :| forall X :: X !in L ==> exp_lc(open_te(e.te0, typ_fvar(X)));
    var L' := L+{Z};
    forall (X | X !in L')
    ensures exp_lc(open_te(subst_te(Z, P, e.te0), typ_fvar(X)));
    {
      lemma_subst_te_expr(Z, P, open_te(e.te0, typ_fvar(X)));
      lemma_subst_te_open_te_var(Z, X, P, e.te0);
    }
  }
}

ghost method lemma_subst_ee_expr(z: int, e1: exp, e2: exp)
  requires exp_lc(e1);
  requires exp_lc(e2);
  ensures exp_lc(subst_ee(z, e2, e1));
  decreases exp_size(e1);
{
  if (e1.exp_abs?) {
    var L:set<int> :| forall x :: x !in L ==> exp_lc(open_ee(e1.e0, exp_fvar(x)));
    var L' := L+{z};
    forall (x | x !in L')
    ensures exp_lc(open_ee(subst_ee(z, e2, e1.e0), exp_fvar(x)));
    {
      lemma_subst_ee_expr(z, open_ee(e1.e0, exp_fvar(x)), e2);
      lemma_subst_ee_open_ee_var(z, x, e2, e1.e0);
    }
  } else if (e1.exp_tabs?) {
    var L:set<int> :| forall X :: X !in L ==> exp_lc(open_te(e1.te0, typ_fvar(X)));
    forall (X | X !in L)
    ensures exp_lc(open_te(subst_ee(z, e2, e1.te0), typ_fvar(X)));
    {
      lemma_subst_ee_expr(z, open_te(e1.te0, typ_fvar(X)), e2);
      lemma_subst_ee_open_te_var(z, X, e2, e1.te0);
    }
  }
}
