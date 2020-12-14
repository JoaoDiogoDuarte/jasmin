(* ** License
 * -----------------------------------------------------------------------
 * Copyright 2016--2017 IMDEA Software Institute
 * Copyright 2016--2017 Inria
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 * ----------------------------------------------------------------------- *)

(* * Syntax and semantics of the linear language *)

(* ** Imports and settings *)
Require Import Setoid Morphisms.

From mathcomp Require Import all_ssreflect all_algebra.
Require Import ZArith Utf8.
        Import Relations.

Require Import psem compiler_util stack_alloc stack_sem.
Require Export linear linear_sem trelation.
        Import Memory.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Local Open Scope seq_scope.

(*Lemma is_labelP i lbl: reflect (exists a, i.(li_i) = Llabel a lbl) (is_label lbl i).
Proof.
  rewrite /is_label;case:i => ii [|a l||] //=; try by constructor => -[].
  apply:(@equivP (lbl = l)); first by apply eqP.
  split=> [->|[? [? ->]] //];eauto.
Qed.
*)

Lemma align_bind ii a p1 l ltc:
  Let p := align ii a p1 in ciok (p.1.1, p.1.2 ++ l, p.2 ++ ltc) =
  align ii a (Let p := p1 in ciok (p.1.1, p.1.2 ++ l, p.2 ++ ltc)).
Proof. by rewrite /align; case: a => //; case: p1. Qed.

Section CAT.

  Let Pi (i:instr) :=
    forall lbl l,
     linear_i i lbl l =
     linear_i i lbl [::] >>= (fun (p:label*lcmd*leak_i_il_tr) => ok (p.1.1, p.1.2 ++ l, p.2)).

  Let Pr (i:instr_r) :=
    forall ii, Pi (MkI ii i).

  Let Pc (c:cmd) :=
    forall lbl l,
     linear_c linear_i c lbl l =
     linear_c linear_i c lbl [::] >>= (fun (p:label*lcmd*seq leak_i_il_tr) => ok (p.1.1, p.1.2 ++ l, p.2)).

  Let Pf (fd:fundef) := True.

  Let HmkI: forall i ii, Pr i -> Pi (MkI ii i).
  Proof. by []. Qed.

  Let Hskip : Pc [::].
  Proof. by []. Qed.

  Let Hseq : forall i c,  Pi i -> Pc c -> Pc (i::c).
  Proof.
    move=> i c Hi Hc lbl l /=.
    rewrite Hc !bindA;apply bind_eq => //= p.
    rewrite Hi (Hi p.1.1 p.1.2) bindA.
    by case heqi : linear_i=> //=; rewrite catA.
  Qed.

  Let Hassgn : forall x tg ty e, Pr (Cassgn x tg ty e).
  Proof. by move => x tg [] // sz e ii lbl c /=; case: assert. Qed.

  Let Hopn : forall xs t o es, Pr (Copn xs t o es).
  Proof. by []. Qed.

  Let Hif   : forall e c1 c2,  Pc c1 -> Pc c2 -> Pr (Cif e c1 c2).
  Proof.
    move=> e c1 c2 Hc1 Hc2 ii lbl l /=.
    case Heq1: (c1)=> [|i1 l1].
    + by rewrite Hc2 (Hc2 _ [::_]) !bindA;apply bind_eq => //= p;rewrite -catA.
    rewrite -Heq1=> {Heq1 i1 l1};case Heq2: (c2)=> [|i2 l2].
    + by rewrite Hc1 (Hc1 _ [::_]) !bindA;apply bind_eq => //= p;rewrite -catA.
    rewrite -Heq2=> {Heq2 i2 l2}.
    rewrite Hc1 (Hc1 _ [::_]) !bindA;apply bind_eq => //= p.
    rewrite Hc2 (Hc2 _ [::_ & _])!bindA;apply bind_eq => //= p1.
    by rewrite -!catA /= -catA.
  Qed.

  Let Hfor : forall v dir lo hi c, Pc c -> Pr (Cfor v (dir, lo, hi) c).
  Proof. by []. Qed.

  Let Hwhile : forall a c e c', Pc c -> Pc c' -> Pr (Cwhile a c e c').
  Proof.
  move=> a c e c' Hc Hc' ii lbl l /=.
  case: is_bool => [[] |].
  (*+ rewrite Hc' (Hc' _ [:: _]) !bindA; f_equal.
   move=> a c e c' Hc Hc' ii lbl l /=.
    case: is_bool => [ [] | ].
    + rewrite Hc' (Hc' _ [:: _]) align_bind !bindA; f_equal;apply bind_eq => //= p.
      by rewrite Hc (Hc _ ( _ ++ _)) !bindA;apply bind_eq => //= p';rewrite -catA /= -catA /=.
    + by apply Hc.
    case: c' Hc' => [ _ | i c' ].
    + by rewrite Hc (Hc _ [:: _]) align_bind !bindA; f_equal; apply bind_eq => //= p; rewrite -catA.
    move: (i :: c') => { i c' } c' Hc'.
    rewrite Hc (Hc _ [:: _]) !bindA; apply bind_eq => //= p.
    rewrite Hc' (Hc' _ (_ :: _)) !bindA; apply bind_eq=> //= p'.
    by case: a => /=; rewrite -catA /= -catA /=.*)
  Admitted.

  Let Hcall : forall i xs f es, Pr (Ccall i xs f es).
  Proof. by []. Qed.

  Lemma linear_i_nil i lbl l :
     linear_i i lbl l =
     linear_i i lbl [::] >>= (fun (p:label*lcmd*leak_i_il_tr) => ok (p.1.1, p.1.2 ++ l, p.2)).
  Proof.
    apply (@instr_Rect Pr Pi Pc HmkI Hskip Hseq Hassgn Hopn Hif Hfor Hwhile Hcall).
  Qed.

  Lemma linear_c_nil c lbl l :
     linear_c linear_i c lbl l =
     linear_c linear_i c lbl [::] >>= (fun (p:label*lcmd*seq leak_i_il_tr) => 
     ok (p.1.1, p.1.2 ++ l, p.2)).
  Proof.
    apply (@cmd_rect Pr Pi Pc HmkI Hskip Hseq Hassgn Hopn Hif Hfor Hwhile Hcall).
  Qed.

End CAT.

(* checks the range of label *)
Definition valid min max lc :=
  all (fun (i: linstr) => let (ii, ir) := i in match ir with
       | Lilabel   lbl => ((min <=? lbl) && (lbl <? max))%positive
       | Ligoto    lbl => ((min <=? lbl) && (lbl <? max))%positive
       | Licond _  lbl => ((min <=? lbl) && (lbl <? max))%positive
       | _            => true
       end) lc.

Lemma valid_cat min max lc1 lc2 :
  valid min max (lc1 ++ lc2) = valid min max lc1 && valid min max lc2.
Proof. by rewrite /valid all_cat. Qed.


Lemma valid_add_align lbl1 lbl2 ii a c :
  valid lbl1 lbl2 (add_align ii a c) = valid lbl1 lbl2 c.
Proof. by rewrite /add_align; case: a. Qed.

Lemma valid_le_min min2 min1 max lc :
  (min1 <=? min2)%positive ->
  valid min2 max lc ->
  valid min1 max lc.
Proof.
  by move=> Hle1; apply: sub_all=> -[ii [||lbl|lbl|e lbl]] //= /andP [] Hle2 ->;
  rewrite (Pos_leb_trans Hle1 Hle2).
Qed.

Lemma valid_le_max max2 max1 min lc :
  (max1 <=? max2)%positive ->
  valid min max1 lc ->
  valid min max2 lc.
Proof.
  by move=> Hle1; apply sub_all=> -[ii [||lbl|lbl|e lbl]] //= /andP [] -> Hlt1 /=;
   rewrite (Pos_lt_leb_trans Hlt1 Hle1).
Qed.

Lemma le_next lbl : (lbl <=? next_lbl lbl)%positive.
Proof.
  by apply Pos.leb_le; have: (Zpos lbl <= Zpos lbl + 1)%Z by omega.
Qed.

Lemma lt_next lbl : (lbl <? next_lbl lbl)%positive.
Proof.
  by apply Pos.ltb_lt; have: (Zpos lbl < Zpos lbl + 1)%Z by omega.
Qed.

Lemma find_label_cat_tl c2 c1 lbl p:
  find_label lbl c1 = ok p -> find_label lbl (c1++c2) = ok p.
Proof.
  rewrite /find_label;case:ifPn => // Hs [<-].
  by rewrite find_cat size_cat has_find Hs (ltn_addr _ Hs).
Qed.

(* TODO move this *)
Lemma onth_cat T (s1 s2 : seq T) n :
  oseq.onth (s1 ++ s2) n = (if n < size s1 then oseq.onth s1 n else oseq.onth s2 (n - size s1)).
Proof. by rewrite !oseq.onth_nth map_cat nth_cat size_map. Qed.

Lemma find_instr_cat_tl c s i :
  find_instr s = Some i ->
  find_instr (setc s (lc s ++ c)) = Some i.
Proof.
  rewrite /setc /find_instr /= => /(oseq.onthP i) /andP [Hs Hnth].
  by apply /(oseq.onthP i);rewrite size_cat nth_cat Hs (ltn_addr _ Hs).
Qed.

Lemma to_estate_setc s c : to_estate (setc s c) = to_estate s.
Proof. by case: s. Qed.

Lemma lsem_cat_tl c2 gd s1 s2 l1: lsem gd s1 l1 s2 ->
  lsem gd (setc s1 (s1.(lc)++c2)) l1 (setc s2 (s2.(lc)++c2)).
Proof.
  move=> H; elim H using lsem_ind; clear. once (econstructor; fail).
  move=> s1 l1 s2 l2 s3 Hsem1 Hsem.
  apply: lsem_step.
  move: Hsem1;rewrite /lsem1 /step.
  case Heq : find_instr => [i |//].
  rewrite (find_instr_cat_tl c2 Heq) /eval_instr => {Heq}; case: i => [ii [lv o e||l|l|e l]] /=;
    rewrite ?to_estate_setc;t_xrbindP.
  + by move=> [[m vm] l] /= -> <- <- /=;case: s1=> //=.
  + by move=> <- <- ;case:s1.
  + by move=> <- <-;case:s1.
  + by move=> y /(find_label_cat_tl c2) -> <- <- /=;case:s1.
  move=> -[vb lb] -> b /= -> /= ;case:b.
  + by t_xrbindP => pc /(find_label_cat_tl c2) -> <- <- /=;case:s1.
  by move=> [<- <-];case:s1.
Qed.

(*
Lemma valid_find_label p1 p2 c c' lbl:
  valid p1 p2 c ->
  find_label lbl c = Some c' ->
  valid p1 p2 c'.
Proof.
  elim: c => //= -[ii [| b| lbl'|lbl'|e lbl']] l Hrec //= /andP[_ H];
    move:(H) => /Hrec H' //.
  by case:ifP => [_[]<-|_].
Qed. *)

Definition is_jump lbl (i:linstr) :=
 let (ii, ir) := i in
 match ir with
 | Ligoto lbl' => lbl == lbl'
 | Licond _ lbl' => lbl == lbl'
 | _ => false
end.

Lemma find_label_cat_hd lbl c1 c2:
  ~~ has (is_label lbl) c1 ->
  find_label lbl (c1 ++ c2) =
  (Let pc := find_label lbl c2 in ok (size c1 + pc)).
Proof.
  rewrite /find_label find_cat size_cat => /negbTE ->.
  by rewrite ltn_add2l;case:ifP.
Qed.

Definition disjoint_lbl c1 c2 :=
  forall lbl, ~~(has (is_label lbl) c1 && has (is_jump lbl) c2).

Lemma disjoint_lbl_cons i c1 c2:
  disjoint_lbl c1 (i :: c2) -> disjoint_lbl c1 c2.
Proof.
  by move=> Hd lbl;apply: contra (Hd lbl)=> /= /andP[]->->;rewrite orbC.
Qed.

(*
Lemma disjoint_find_label c1 c2 c lbl:
  disjoint_lbl c1 c2 ->
  find_label lbl c2 = Some pc ->
  disjoint_lbl c1 c.
Proof.
  elim: c2 => //= i c2 Hrec Hd.
  have H:= (disjoint_lbl_cons Hd); have {Hrec}Hrec := Hrec H.
  by case:ifP => //= ? [] <-.
Qed.
*)

Definition add_hd_c c s := {| lmem := lmem s; lvm := lvm s; lc := c ++ s.(lc); lpc := size c + s.(lpc) |}.

Lemma lsem1_lc gb s1 s2 l1: lsem1 gb s1 l1 s2 -> lc s1 = lc s2.
Proof.
  rewrite /lsem1 /step;case: find_instr => // -[ii [lv o e||l|l|e l]] /=;
    rewrite /eval_instr /=;t_xrbindP.
  + by move=> ?? <-.
  + by move=> <-.
  + by move=> <-.
  + by move=> ?? <-.
  move=> ????;case:ifP => [ ? | ? [<-] //].
  by t_xrbindP => ?? <-.
Qed.

Lemma find_instr_add_hd_c c s : find_instr (add_hd_c c s) = find_instr s.
Proof.
  rewrite /find_instr /add_hd_c /= !oseq.onth_nth map_cat nth_cat size_map.
  rewrite ltnNge leq_addr /=;f_equal;rewrite -minusE -plusE; omega.
Qed.

Lemma to_estate_add_hd_c c s : to_estate (add_hd_c c s) = to_estate s.
Proof. by case: s. Qed.

Lemma find_instr_has (p:linstr->bool) s i :
  find_instr s = Some i -> p i -> has p (lc s).
Proof.
  rewrite /find_instr => /(oseq.onthP i) => /andP [H1 /eqP <-] Hp.
  apply /(has_nthP i);eauto.
Qed.

Lemma lsem_cat_hd c gd s1 s2 l1:
  disjoint_lbl c s1.(lc) ->
  lsem gd s1 l1 s2 ->
  lsem gd (add_hd_c c s1) l1 (add_hd_c c s2).
Proof.
  move=> Hdisj Hsem; revert Hdisj.
  elim/lsem_ind: Hsem; clear.
  (* reflexive case *)
  + by move=> s1 Hdisjc; apply: tc_refl.
  move=> s1 l1 s2 l2 s3 Hsem1 Hsem Hrec Hdisj.
  move: Hrec;rewrite -(lsem1_lc Hsem1) => /(_ Hdisj); apply: lsem_step.
  move: Hsem1;rewrite /lsem1 /step.
  have Hnext : forall s s1,
    of_estate s (c ++ lc s1) (size c + lpc s1).+1 = add_hd_c c (of_estate s (lc s1) (lpc s1).+1).
  + by move=> s [????];rewrite /of_estate /add_hd_c /= addnS.
  have Hset : forall pc s1,
    setpc (add_hd_c c s1) (size c + pc).+1 = add_hd_c c (setpc s1 pc.+1).
  + by move=> pc [????];rewrite /setpc /add_hd_c /= addnS.
  rewrite find_instr_add_hd_c;case Heq:find_instr => [ [ii [lv o e||l|l|e l]] | //];
    rewrite /eval_instr /= ?to_estate_add_hd_c;t_xrbindP.
  + by move=> ? -> <- <- /=;rewrite Hnext.
  + by move=> <- <-;rewrite Hset.
  + by move=> <- <-;rewrite Hset.
  + move=> pc' Hfind <- <-.
    rewrite find_label_cat_hd ?Hfind /= ? Hset //.
    by move: (Hdisj l);rewrite /disjoint_lbl (@find_instr_has (is_jump l) _ _ Heq) ?andbT /is_jump.
  move=> -[vb lb] -> b /= -> /=;case:ifPn => Hb.
  + t_xrbindP => n Hfind <- <-.
    rewrite find_label_cat_hd ?Hfind /= ? Hset //.
    move: (Hdisj l);rewrite /disjoint_lbl (@find_instr_has (is_jump l) _ _ Heq) ?andbT /is_jump.
    by move=> h; case: b Hb => //=; auto. auto. 
    by move: (Hdisj l);rewrite /disjoint_lbl (@find_instr_has (is_jump l) _ _ Heq) ?andbT /is_jump. 
  by move=> [<- <-];rewrite Hset; case: b Hb => //=.
Qed.

Lemma valid_has c lbl p1 p2 :
  valid p1 p2 c -> has (is_label lbl) c || has (is_jump lbl) c ->
  ((p1 <=? lbl) && (lbl <? p2))%positive.
Proof.
  elim: c => //= i c Hrec /andP[] H /Hrec.
  by case: i H=>[ii [||lbl'|lbl'|e lbl']] //=;
  rewrite {2}/is_label /=; case: eqP=> [->|].
Qed.

Lemma valid_disjoint p1 p2 p3 p4 c1 c2 :
  ((p2 <=? p3) || (p4 <=? p1))%positive ->
  valid p1 p2 c1 ->
  valid p3 p4 c2 ->
  disjoint_lbl c1 c2.
Proof.
  move=> Hp Hv1 Hv2 lbl;apply /negP=>/andP[] H1 H2.
  have := @valid_has _ lbl _ _ Hv1;rewrite H1=> /(_ isT) /andP[]/P_leP ? /P_ltP ?.
  have := @valid_has _ lbl _ _ Hv2;rewrite H2 orbT => /(_ isT) /andP[]/P_leP ? /P_ltP ?.
  case/orP: Hp => /P_leP ?;omega.
Qed.

Lemma disjoint_cat_l c1 c2 c :
  disjoint_lbl (c1++c2) c <-> (disjoint_lbl c1 c /\ disjoint_lbl c2 c).
Proof.
  rewrite /disjoint_lbl;split.
  + move=> H1;split=> lbl;have := H1 lbl;rewrite has_cat;apply contra=>/andP[]->->//.
    by rewrite orbC.
  move=> [H1 H2] lbl;rewrite has_cat;apply /negP => /andP[]/orP []H H'.
  + by move: (H1 lbl);rewrite H H'.
  by move: (H2 lbl);rewrite H H'.
Qed.

Lemma disjoint_cat_r c1 c2 c :
  disjoint_lbl c (c1++c2) <-> (disjoint_lbl c c1 /\ disjoint_lbl c c2).
Proof.
  rewrite /disjoint_lbl;split.
  + move=> H1;split=> lbl;have := H1 lbl;rewrite has_cat;apply contra=>/andP[]->->//.
    by rewrite orbC.
  move=> [H1 H2] lbl;rewrite has_cat;apply /negP => /andP[] H /orP[]H'.
  + by move: (H1 lbl);rewrite H H'.
  by move: (H2 lbl);rewrite H H'.
Qed.

(** need to make proof shorter *)
Lemma snot_spec gd s e b le pstk:
  let r := (snot e) in
  sem_pexpr gd s e = ok (Vbool b, le) →
  sem_pexpr gd s r.1 = ok(Vbool (negb b), leak_E pstk r.2 le).
Proof.
elim: e b le=> //=; try auto.
(* Pbool *)
- by move=> b b0 le [] <- <-.
(* Pvar *)
- by move=> x b le; t_xrbindP=> vg -> -> <- /=.
(* Pglobal *)
- by move=> g b le; t_xrbindP=> vg -> -> <- /=. 
(* Pget *)
- move=> sz x e He b le /=. 
  apply: on_arr_varP => n t Hsub; rewrite /on_arr_var => -> /=; t_xrbindP.
  move=> [v l] -> /= z -> sz' /= -> /= //=.
(* Pload *)
- move=> sz x e He b le /=. t_xrbindP. 
  move=> u v -> hp [v' l'] -> u' /= hp' sz' hm /=.
  move=> //=. 
(* Papp1 *)
- case=> // sz e //=.
  (* op = Oword_of_int *)
  + t_xrbindP. move=> He b le. rewrite /sem_sop1 /=.
    move=> [v l] -> /= vo. t_xrbindP. move=> z -> <- //=.
  (* op = Oint_of_word *)
  + t_xrbindP. move=> He b le. rewrite /sem_sop1 /=.
    move=> [v l] -> /= vo. t_xrbindP. move=> z hi <- //=.
  (* op = Osignnext *)
  + move=> e' He. rewrite /sem_sop1 /=.
    move=> b' le. t_xrbindP. move=>[v l] -> /= vo we -> //= <- //=. 
  (* op = Ozeronext *)
  + t_xrbindP. move=> e' He. rewrite /sem_sop1 /=.
    move=> b' le [v l] -> /= vo. t_xrbindP. move=> z -> <- //=.
  (* op = Onot *)
  + t_xrbindP. rewrite /sem_sop1 /=.
    move=> b le [v l] -> /= vo. t_xrbindP=> vb /to_boolI //= -> <- [] <- <- //=. by rewrite negbK.
  (* op = Olnot *)
  + t_xrbindP. move=> He b le. rewrite /sem_sop1 /=.
    move=> [v l] -> /= vo. t_xrbindP. move=> z -> <- //=.
  (* op = Oneg *)
  by t_xrbindP; move=> He b le [v l] -> vo /= -> //= -> -> /=.
(* Papp2 *)
- case=> //=.
  + move=> e1 He1 e2 He2 b le /=; t_xrbindP. 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo.
    move=>/sem_sop2I [b1 [b2 [b3]]] [] /to_boolI /= hb1 /to_boolI /= hb2 [h] h' h'' <- /=.
    rewrite hb1 in h1. rewrite hb2 in h2. move: (He1 b1 l1 h1). move=> -> /=.
    move: (He2 b2 l2 h2). move=> -> /=; apply: (f_equal (@Ok _ _)); rewrite /= ?negb_and ?negb_or /=.
    rewrite h'' in h'. case: h'=> h1'. rewrite -h1' in h. rewrite -h /= negb_and. auto.
  + move=> e1 He1 e2 He2 b le /=; t_xrbindP. 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo.
    move=>/sem_sop2I [b1 [b2 [b3]]] [] /to_boolI /= hb1 /to_boolI /= hb2 [h] h' h'' <- /=.
    rewrite hb1 in h1. rewrite hb2 in h2. move: (He1 b1 l1 h1). move=> -> /=.
    move: (He2 b2 l2 h2). move=> -> /=; apply: (f_equal (@Ok _ _)); rewrite /= ?negb_and ?negb_or /=.
    rewrite h'' in h'. case: h'=> h1'. rewrite -h1' in h. rewrite -h /= negb_or. auto.
  + move=> o e1 He1 e2 He2 b le /=; t_xrbindP. 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=. rewrite h1 /= h2 /= ho /=.
    rewrite /sem_sop1 /=. by rewrite hb /=.
  + move=> o e1 He1 e2 He2 b le /=; t_xrbindP. 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=. rewrite h1 /= h2 /= ho /=.
    rewrite /sem_sop1 /=. by rewrite hb /=.
  + move=> o e1 He1 e2 He2 b le /=; t_xrbindP. 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=. rewrite h1 /= h2 /= ho /=.
    rewrite /sem_sop1 /=. by rewrite hb /=.
  + move=> o e1 He1 e2 He2 b le /=; t_xrbindP. 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=. rewrite h1 /= h2 /= ho /=.
    rewrite /sem_sop1 /=. by rewrite hb /=.
  + move=> o e1 He1 e2 He2 b le /=; t_xrbindP. 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=. rewrite h1 /= h2 /= ho /=.
    rewrite /sem_sop1 /=. by rewrite hb /=.
  + move=> o e1 He1 e2 He2 b le /=; t_xrbindP. 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=. rewrite h1 /= h2 /= ho /=.
    rewrite /sem_sop1 /=. by rewrite hb /=.
  + move=> o e1 He1 e2 He2 b le /=; t_xrbindP. 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=. rewrite h1 /= h2 /= ho /=.
    rewrite /sem_sop1 /=. by rewrite hb /=.
  + move=> o e1 He1 e2 He2 b le /=; t_xrbindP. 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=. rewrite h1 /= h2 /= ho /=.
    rewrite /sem_sop1 /=. by rewrite hb /=.
  + move=> o e1 He1 e2 He2 b le /=; t_xrbindP. 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=. rewrite h1 /= h2 /= ho /=.
    rewrite /sem_sop1 /=. by rewrite hb /=.
  + move=> o e1 He1 e2 He2 b le /=; t_xrbindP. 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=. rewrite h1 /= h2 /= ho /=.
    rewrite /sem_sop1 /=. by rewrite hb /=.
  + move=> o e1 He1 e2 He2 b le /=; t_xrbindP. 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=. rewrite h1 /= h2 /= ho /=.
    rewrite /sem_sop1 /=. by rewrite hb /=.
  + move=> o e1 He1 e2 He2 b le /=; t_xrbindP; 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=; rewrite h1 /= h2 /= ho /=;
    rewrite /sem_sop1 /=; by rewrite hb /=.
  + move=> o e1 He1 e2 He2 b le /=; t_xrbindP; 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=; rewrite h1 /= h2 /= ho /=;
    rewrite /sem_sop1 /=; by rewrite hb /=.
  + move=> o e1 He1 e2 He2 b le /=; t_xrbindP; 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=; rewrite h1 /= h2 /= ho /=;
    rewrite /sem_sop1 /=; by rewrite hb /=.
  + move=> o e1 He1 e2 He2 b le /=; t_xrbindP; 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=; rewrite h1 /= h2 /= ho /=;
    rewrite /sem_sop1 /=; by rewrite hb /=.
  + move=> o e1 He1 e2 He2 b le /=; t_xrbindP; 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=; rewrite h1 /= h2 /= ho /=;
    rewrite /sem_sop1 /=; by rewrite hb /=.
  + move=> o e1 He1 e2 He2 b le /=; t_xrbindP; 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=; rewrite h1 /= h2 /= ho /=;
    rewrite /sem_sop1 /=; by rewrite hb /=.
  + move=> o o' e1 He1 e2 He2 b le /=; t_xrbindP;
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=; rewrite h1 /= h2 /= ho /=;
    rewrite /sem_sop1 /=; by rewrite hb /=.
  + move=> o o' e1 He1 e2 He2 b le /=; t_xrbindP; 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=; rewrite h1 /= h2 /= ho /=;
    rewrite /sem_sop1 /=; by rewrite hb /=.
  + move=> o o' e1 He1 e2 He2 b le /=; t_xrbindP; 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=; rewrite h1 /= h2 /= ho /=;
    rewrite /sem_sop1 /=; by rewrite hb /=.
  + move=> o o' e1 He1 e2 He2 b le /=; t_xrbindP; 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=; rewrite h1 /= h2 /= ho /=;
    rewrite /sem_sop1 /=; by rewrite hb /=.
  + move=> o o' e1 He1 e2 He2 b le /=; t_xrbindP; 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=; rewrite h1 /= h2 /= ho /=;
    rewrite /sem_sop1 /=; by rewrite hb /=.
  + move=> o o' e1 He1 e2 He2 b le /=; t_xrbindP; 
    move=>[v1 l1] h1 [v2 l2] h2; move=> vo //= ho hb <- /=; rewrite h1 /= h2 /= ho /=;
    rewrite /sem_sop1 /=; by rewrite hb /=.
(* PopN *)
- move=> op es He b le. t_xrbindP.
  move=> vs -> vo ho hb <- /=. rewrite ho /=. by rewrite /sem_sop1 /= hb /=.
(* Pif *)
move => st p hp e1 he1 e2 he2 b l /=.
t_xrbindP => -[vp lp] -> /= bp -> /= [v1 l1] h1 [v2 l2] h2 trv1 htr1 trv2 htr2 /= h <-.
have : exists (b1 b2:bool), st = sbool /\ sem_pexpr gd s e1 = ok (Vbool b1, l1) /\ sem_pexpr gd s e2 = ok (Vbool b2, l2).
+ rewrite h1 h2;case: bp h => ?;subst.
  + have [h /= h']:= truncate_val_boolI htr1; subst st v1.
    by move: htr2; rewrite /truncate_val; t_xrbindP => /= b2 /to_boolI -> ?;eauto.
  have [h /= h']:= truncate_val_boolI htr2;subst st v2.
  by move: htr1; rewrite /truncate_val; t_xrbindP => /= b1 /to_boolI -> ?;eauto.
move=> [b1 [b2 [-> []/dup[]hb1 /he1 -> /dup[]hb2 /he2 ->]]] /=.
rewrite hb1 in h1. rewrite hb2 in h2. case: h1=> h11. case: h2=> h12. rewrite -h11 in htr1.
rewrite /= in htr1. rewrite -h12 in htr2. rewrite /= in htr2.
move: truncate_val_bool. move=> Ht. move: (Ht st b1 trv1 htr1). move=> [] _ hbb.
move: (Ht st b2 trv2 htr2). move=> [] _ hbb'. rewrite hbb in h. rewrite hbb' in h.
case: bp h => //=. by move=> [] ->. by move=> [] ->.
Qed.

Lemma lsem_add_align gd s c ii a s' li :
  lsem gd (of_estate s c 0) li (of_estate s' c (size c)) ->
  lsem gd (of_estate s (add_align ii a c) 0) (get_align_leak_il a ++ li)  (of_estate s' (add_align ii a c) (size (add_align ii a c))).
Proof.
  rewrite /add_align;case: a s s' => -[] m vm [] m' vm' h //.
  apply: lsem_step. constructor.
  by apply: (lsem_cat_hd (c:=[::{| li_ii := ii; li_i := Lialign |}]) _ h).
Qed.

Lemma add_align_nil ii a c : add_align ii a c = add_align ii a [::] ++ c.
Proof. by case: a. Qed.

Lemma find_label_add_align lbl ii a c :
  find_label lbl (add_align ii a c) =
  Let n := find_label lbl c in ok ((a == Align) + n).
Proof.
  case: a => /=;last by case: find_label.
  by rewrite /add_align -cat1s find_label_cat_hd.
Qed.

Section PROOF.

  Variable p:  sprog.
  Context (gd: glob_decls).
  Variable p': lprog.
  Variable stk : pointer.
  Variable Fs : seq(funname * seq leak_i_il_tr).
  Hypothesis linear_ok : linear_prog p = ok (p', Fs).

  Let Pi (i:instr) :=
    forall lbl lbli li lti, linear_i i lbl [::] = ok (lbli, li, lti) ->
    [/\ (lbl <=? lbli)%positive,
     valid lbl lbli li &
     forall s1 s2 l, S.sem_I p gd s1 i l s2 ->
     lsem gd (of_estate s1 li 0) (leak_i_iL stk l lti) (of_estate s2 li (size li))].

  Let Pi_r (i:instr_r) :=
    forall ii lbl lbli li lti, linear_i (MkI ii i) lbl [::] = ok (lbli, li, lti) ->
    [/\ (lbl <=? lbli)%positive,
     valid lbl lbli li &
     forall s1 s2 l, S.sem_i p gd s1 i l s2 ->
       lsem gd (of_estate s1 li 0) (leak_i_iL stk l lti) (of_estate s2 li (size li))].

  Let Pc (c:cmd) :=
    forall lbl lblc lc ltc, linear_c linear_i c lbl [::] = ok (lblc, lc, ltc) ->
    [/\ (lbl <=? lblc)%positive,
     valid lbl lblc lc &
     forall s1 s2 l, S.sem p gd s1 c l s2 ->
       lsem gd (of_estate s1 lc 0) 
         (leak_i_iLs (leak_i_iL) stk ltc l)
        (of_estate s2 lc (size lc))].

  Let HmkI : forall i ii, Pi_r i -> Pi (MkI ii i).
  Proof.
    move=> i ii Hi_r lbl lbli li lti Hli.
    move: Hi_r=> /(_ ii lbl lbli li lti Hli) [H1 H2 H3]; split=> //.
    move=> s1 s2 l /S.sem_IE; apply H3.
  Qed.

  Let Hskip : Pc [::].
  Proof.
    move=> lbl lbli li ltc /= [] <- <-;split=> //. apply Pos.leb_refl.
    move=> s1 s2 l /S.semE [] -> ->; apply tc_refl.
  Qed.

  Lemma of_estate_add_hd_c s li lc pc:
    add_hd_c li (of_estate s lc pc) = of_estate s (li ++ lc) (size li + pc).
  Proof. done. Qed.

  Let Hseq : forall i c,  Pi i -> Pc c -> Pc (i::c).
  Proof.
    move=> i c Hi Hc lbl lbl' l ltc /=.
    case Heqc : linear_c => [[[lblc lc] ltc']|] //=.
    rewrite /Pc in Hc. move: (Hc lbl lblc lc ltc' Heqc).
    move=> {Hc} [] Hle1 Hvc Hc.
    rewrite linear_i_nil.
    case Heqi: linear_i => [[[lbli li] lti]|] //= [] h1 h2 h3 ;subst lbl' l ltc.
    rewrite /Pi in Hi. move: (Hi lblc lbli li lti Heqi).
    move=> {Hi} [] Hle2 Hvi Hi; split.
    + by apply /P_leP;move/P_leP: Hle1;move/P_leP: Hle2=> ??;omega.
    + by rewrite valid_cat (valid_le_min Hle1 Hvi) (valid_le_max Hle2 Hvc).
    move=> -[m1 vm1] s2 l /S.semE [[m2 vm2]] [li'] [lc'] [] Hi' Hc' ->.
    rewrite /lsem /=.
    apply tc_trans  with (of_estate {| emem := m2; evm := vm2 |} (li++lc) (size li)).
    + by apply (lsem_cat_tl lc (Hi _ _ _ Hi')).
    have Hvc1 : valid 1 lblc lc.
    apply: valid_le_min Hvc.
    + by rewrite /is_true Pos.leb_le;apply Pos.le_1_l.
    + move: (Hc {| emem := m2; evm := vm2 |} s2 lc' Hc'). move=> {Hc} Hc.
    have /(@lsem_cat_hd li) := Hc.
    rewrite !of_estate_add_hd_c size_cat addn0;apply.
    by apply: valid_disjoint Hvi Hvc;rewrite Pos.leb_refl orbC.
  Qed.
    
  Lemma to_of_estate s c pc : to_estate (of_estate s c pc) = s.
  Proof. by case: s. Qed.

  Let Hassgn : forall x tag ty e, Pi_r (Cassgn x tag ty e).
  Proof.
    move=> x tag [] // sz e ii lbl lbl' l ltc /= [] <- <- <-;rewrite Pos.leb_refl; split => //.
    move=> -[m1 vm1] s2 l' /S.sem_iE' [v] [v'] [le] [lw] [ok_v].
    apply: rbindP => w /of_val_word [sz'] [w'] [hle h1 h2]; subst v w => - [<-] {v'} ok_s2 ->.
    rewrite /lsem /=. apply tc_step. rewrite /lsem1 /step /= /eval_instr /= !to_of_estate.
    case: ifP => hsz.
    + by rewrite /sem_sopn /sem_pexprs /= /exec_sopn /sopn_sem /= ok_v /= 
      /truncate_word hle /x86_MOV /check_size_8_64 hsz /= ok_s2 /=. 
    by rewrite /sem_sopn /= /exec_sopn /sopn_sem /= ok_v /= /truncate_word hle /=
    /x86_VMOVDQU (wsize_nle_u64_check_128_256 hsz) /= ok_s2 /=. 
  Qed.

  Let Hopn : forall xs t o es, Pi_r (Copn xs t o es).
  Proof.
    move=> x t' e tag ii lbl lbl' l' lti [] <- <- <-;rewrite Pos.leb_refl;split=>//.
    move=> -[m1 vm1] s2 l /S.sem_iE' [] lo [] ok_s2 ->. rewrite /lsem. apply tc_step.
    by rewrite /lsem1 /step /= /eval_instr /= !to_of_estate /= ok_s2 /=.
  Qed.

  Lemma find_label_hd lbl ii c :
    find_label lbl ({|li_ii:= ii; li_i := Lilabel lbl|} :: c ) = ok 0.
  Proof. by rewrite /find_label /= /is_label /= eqxx. Qed.

  Lemma setc_of_estate s c pc c' :setc (of_estate s c pc) c' = of_estate s c' pc.
  Proof. done. Qed.

  Let Hif   : forall e c1 c2,  Pc c1 -> Pc c2 -> Pi_r (Cif e c1 c2).
  Proof.
    move=> e c1 c2 Hc1 Hc2 ii lbl lbl' l' lti /=.
    case Heq1: (c1)=> [|i1 l1].
    (* case1: Cif e [::] c2 *) (* finished *)
    + subst;rewrite linear_c_nil;case Heq: linear_c => [[[lbl2 lc2] ltc2]|] //= [] <- <- <-.
      have Hlen := le_next lbl.
      have [Hle Hv2 Hs2]:= Hc2 _ _ _ _ Heq;split.
      + by apply: Pos_leb_trans Hle.
      + rewrite /= valid_cat Pos.leb_refl (valid_le_min Hlen Hv2) /= Pos.leb_refl.
        by rewrite (Pos_lt_leb_trans (lt_next _) Hle).
      move => [m1 vm1] s2 l /S.sem_iE' [b] [le] [lc] [ok_b ok_s2] ->.
      case: b ok_b ok_s2 => ok_b.
      - move => /S.semE [] -> -> {s2}.
        apply: lsem_step.
        * rewrite /lsem1 /step /= /eval_instr /= !to_of_estate ok_b {ok_b} /=.
          rewrite -cat_cons find_label_cat_hd.
          + by rewrite find_label_hd /=;eauto.
          apply /negP => /= H; have := @valid_has _ lbl _ _ Hv2.
          rewrite H => /(_ erefl) /andP [].
          by rewrite Pos.leb_antisym lt_next.
        rewrite /= size_cat /= addn1 addn0; exact: tc_refl.
      move => ok_s2.
      apply: lsem_step.
      + by rewrite /lsem1 /step /= /eval_instr /= ?to_of_estate ok_b {ok_b} /=.
      move: Hs2 => /(_ _ _ _ ok_s2) Hs2.
      have Hvc : valid lbl (next_lbl lbl) [:: MkLI ii (Licond e lbl)].
      + by rewrite /= Pos.leb_refl lt_next.
      have Hd: disjoint_lbl [:: MkLI ii (Licond e lbl)] lc2 by move=> ?.
      have /(@lsem_cat_tl [:: MkLI ii (Lilabel lbl)]):=
         @lsem_cat_hd [:: MkLI ii (Licond e lbl)] _ _ _ _ Hd Hs2.
      rewrite !of_estate_add_hd_c !addn0 /= => Hsem.
      apply (tc_trans Hsem) => {Hsem}.
      apply tc_step; rewrite /lsem1 /step /= /setc /find_instr /= onth_cat ltnn subnn /=.
      by rewrite /eval_instr /= size_cat /= addn1.
    rewrite -Heq1 => {Heq1 l1 i1};case Heq2: c2 => [|i2 l2].
    (* case 2: Cif e c1 [::] *)
    + subst; rewrite linear_c_nil; case Heq: linear_c=> [[[lbl1 lc1] ltc1]|] //= [] <- <- <-.
      have Hlen := le_next lbl.
      have [Hle Hv1 Hs1]:= Hc1 _ _ _ _ Heq;split.
      + by apply: Pos_leb_trans Hle.
      rewrite /= valid_cat Pos.leb_refl (valid_le_min Hlen Hv1) /= Pos.leb_refl.
      by rewrite (Pos_lt_leb_trans (lt_next _) Hle).
      case => m1 vm1 s2 l /S.sem_iE' [b] [le] [lc]; case: b => ok_b.
      case: ok_b.
      (* true case *)
      + move => ok_e ok_s2 ->.
        apply: lsem_step.
        + rewrite /lsem1 /step /= /eval_instr /= ?to_of_estate. 
          move: snot_spec. move=> /= Hsnot. 
          move: (Hsnot gd {| emem := m1; evm := vm1 |} e true le stk ok_e). move=> {Hsnot} -> /=.
          by rewrite /setpc /=. 
        + move: Hs1 => /(_ _ _ _ ok_s2) Hs1.
          have Hvc : valid lbl (next_lbl lbl) [:: MkLI ii (Licond (Papp1 Onot e) lbl)].
          + by rewrite /= Pos.leb_refl lt_next.
          have Hd: disjoint_lbl [:: MkLI ii (Licond (snot e).1 lbl)] lc1 by move=> ?.
          have := @lsem_cat_hd [:: MkLI ii (Licond (snot e).1 lbl)] _ _ _ _ Hd Hs1.
          move=> /(@lsem_cat_tl [:: MkLI ii (Lilabel lbl)]) Hsem.
          eapply tc_trans. apply Hsem;case s2 => m2 vm2.
          apply tc_step.
          rewrite /lsem1 /step /setc /find_instr /= onth_cat ltnn subnn /=.
          by rewrite /eval_instr /= size_cat /= addn1.
      (* false case *)
      case: ok_b. move=> ok_e /S.semE [] -> -> -> /=.
      apply: lsem_step.
      + rewrite /lsem1 /step /= /eval_instr /= ?to_of_estate. 
        move: snot_spec. move=> /= Hsnot. 
        move: (Hsnot gd {| emem := m1; evm := vm1 |} e false le stk ok_e). 
        move=> {Hsnot} -> /=. 
        rewrite -cat_cons find_label_cat_hd.
        + by rewrite find_label_hd /=;eauto.
        apply /negP => /= H. have := @valid_has _ lbl _ _ Hv1.
        rewrite H => /(_ erefl) /andP [].
        by rewrite Pos.leb_antisym lt_next.
      rewrite /= size_cat /= addn1 addn0;exact: tc_refl.
    (* case 3: Cif e c1 c2 *)
    rewrite -Heq2 => {Heq2 l2 i2}.
    rewrite linear_c_nil;case Heq1: linear_c => [[[lbl1 lc1] ltc1]|] //=.
    rewrite linear_c_nil;case Heq2: linear_c => [[[lbl2 lc2] ltc2]|] //= [] <- <- <-.
    have leL1 := le_next lbl; have leL2 := le_next (next_lbl lbl).
    have [Hle1 Hv1 Hs1]:= Hc1 _ _ _ _ Heq1;have [Hle2 Hv2 Hs2]:= Hc2 _ _ _ _ Heq2.
    have L2lbl2 := Pos_leb_trans Hle1 Hle2.
    have L1lbl2 := Pos_leb_trans leL2 L2lbl2.

    have lblL2 := Pos_leb_trans leL1 leL2.
    have lbllbl1 := Pos_leb_trans lblL2 Hle1;split.
    + by apply: Pos_leb_trans Hle2.
    + rewrite /= valid_cat /= valid_cat /=.
      rewrite Pos.leb_refl leL1 (Pos_lt_leb_trans (lt_next lbl) L1lbl2).
      rewrite (Pos_lt_leb_trans (lt_next _) L2lbl2).
      by rewrite (valid_le_min _ Hv2) // (valid_le_max Hle2 (valid_le_min lblL2 Hv1)).
    move=> [m1 vm1] s2 l /S.sem_iE' [b] [lc] [lc'] [].
    set C := (C in of_estate _ C _); rewrite -/C.
    case: b => ok_b ok_s2 ->.
    + apply lsem_step with (of_estate {| emem := m1; evm := vm1 |} C ((size lc2) .+3)).
      + rewrite /lsem1 /step /= /eval_instr /=  ?to_of_estate ok_b /=.
        rewrite /C -cat_cons -cat_rcons find_label_cat_hd.
        + by rewrite find_label_hd size_rcons /= addn0.
        rewrite has_rcons /=; apply /negP => H; have := @valid_has _ lbl _ _ Hv2. rewrite H=> /(_ isT) /andP[].
        have Hlt := Pos_leb_trans leL2 Hle1.
        by rewrite Pos.leb_antisym (Pos_lt_leb_trans(lt_next _)(Pos_leb_trans leL2 Hle1)).
      move: Hs1 => /(_ _ _ _ ok_s2) Hs1.
      have Hd:
        disjoint_lbl ([:: MkLI ii (Licond e lbl)]++lc2++[:: MkLI ii (Ligoto (next_lbl lbl)); MkLI ii (Lilabel lbl)]) lc1.
      + rewrite !disjoint_cat_l;split;first by move=> ?.
        split;first by apply: valid_disjoint Hv2 Hv1;rewrite Pos.leb_refl orbC.
        move=> lbl0 /=;rewrite orbF /is_label /=;case:eqP=> //= ?;subst lbl0.
        apply /negP => H; have := @valid_has _ lbl _ _ Hv1;rewrite H orbT.
        move=> /(_ isT) /andP[];rewrite Pos.leb_antisym.
        by rewrite (Pos_lt_leb_trans (lt_next _) leL2).
      have /(_ _ Hd) := lsem_cat_hd _ Hs1.
      rewrite !of_estate_add_hd_c /=.
      move=> /(@lsem_cat_tl [:: MkLI ii (Lilabel (next_lbl lbl))]) /=.
      rewrite !setc_of_estate addn0 size_cat /= addn2 /C -!catA /= => Hsem.
      eapply tc_trans. apply Hsem. apply tc_step.
      rewrite /lsem1 /step /setc /find_instr /= onth_cat.
      have -> : ((size lc2 + size lc1)%Nrec.+2 < size lc2) = false.
      + by apply negbTE;apply /ltP;rewrite -addnE -plusE;omega.
      have -> /= : (size lc2 + size lc1)%Nrec.+2 - size lc2 = (size lc1).+2.
      + by rewrite -addnE -minusE -plusE;omega.
      rewrite onth_cat ltnn subnn /= size_cat /= size_cat /eval_instr /=.
      by rewrite !addSn !addnS addn0.
    apply lsem_step with (of_estate {| emem := m1; evm := vm1 |} C 1).
    + by rewrite /lsem1 /step /= /eval_instr /= ?to_of_estate ok_b /=.
    apply tc_trans with (of_estate s2 C (size lc2).+1).
    + have := Hs2 _ _ _ ok_s2.
      move=> /(@lsem_cat_tl [:: MkLI ii (Ligoto (next_lbl lbl)), MkLI ii (Lilabel lbl) & lc1 ++ [:: MkLI ii (Lilabel (next_lbl lbl))]]) /= H.
      by have /= /(_ [:: MkLI ii (Licond e lbl)]) H0 := lsem_cat_hd _ H; apply H0.
    apply tc_step.
    rewrite /lsem1 /step /= /C /find_instr /= onth_cat ltnn subnn /eval_instr /=.
    rewrite -cat_cons -2!cat_rcons catA find_label_cat_hd.
    + by rewrite find_label_hd /= !(size_cat, size_rcons, addn0) /= size_cat /= !addSn addn1 !addnS.
    rewrite has_cat !has_rcons /=.
    rewrite {1}/is_label /=.
    case: eqP => Heq /=.
    + by have := lt_next lbl;rewrite Pos.ltb_antisym Heq Pos.leb_refl.
    apply /negP => /orP [] H.
    + have := @valid_has _ (next_lbl lbl) _ _ Hv2.
      by rewrite H Pos.leb_antisym (Pos_lt_leb_trans (lt_next _) Hle1) /= => /(_ isT).
    have := @valid_has _ (next_lbl lbl) _ _ Hv1.
    by rewrite H Pos.leb_antisym lt_next /= => /(_ isT).
  Qed.

  Let Hfor : forall v dir lo hi c, Pc c -> Pi_r (Cfor v (dir, lo, hi) c).
  Proof. by []. Qed.

  Lemma lc_of_estate s lc pc : linear_sem.lc (of_estate s lc pc) = lc.
  Proof. by case: s. Qed.

  Lemma setpc_of_estate s C pc pc' : setpc (of_estate s C pc) pc' = of_estate s C pc'.
  Proof. done. Qed.

  Let Hwhile' : forall a c e c', Pc c -> Pc c' -> Pi_r (Cwhile a c e c').
  Proof.
    move=> a c e c' Hc Hc' ii lbl lbli li lti /=.
    set ι := MkLI ii.
    case: is_boolP => [[] | {e} e].
    + admit.
    (* case 2: when e is false *) (* done *)
    + rewrite linear_c_nil; case Heqc' : linear_c => [[[lblc' lc'] ltc]|] //=.
      move: Hc. rewrite /Pc. 
      move=> Hc. move: (Hc lbl lblc' lc' ltc Heqc'). move=> [] H1 H2 H3.
      move=> [] <- <- <-; split.
      + auto.
      + rewrite cats0. apply H2.
      + rewrite cats0. move=> s1 s2 l /S.sem_iE' [si] [b] [lc] [le] [Hs] //=.
        move=> [] [] <- <- [] <- -> /=. move: (H3 s1 si lc Hs). move=> {H3} H3.
        apply H3.
    (* case 3 *)
    case: c' Hc' => [ _ | i c' ].
    (* subcase 1 : c' = [::] *)
    + rewrite linear_c_nil;case Heqc: linear_c => [[[lblc lc] ltc]|] //= x.
       apply ok_inj in x. 
      case/xseq.pair_inj: x => -[h1 h2] h3; subst lbli li lti.
      have {Hc}[Hle1 Hvc Hc]:= Hc _ _ _ _ Heqc.
      have leL1 := le_next lbl.
      have ltL1 := lt_next lbl.
      have Hle2 := Pos_leb_trans leL1 Hle1.
      have Hlt := Pos_lt_leb_trans ltL1 Hle1.
      split => //.
      + by rewrite valid_add_align /= valid_cat /= Pos.leb_refl Hlt (valid_le_min _ Hvc).
      move=> s1 s2 li /S.sem_iE'. move=> [si] [b] [lc'] [le] [H] [He].
      case: b He.
      (* b is true *)
      - move=> He [sj] [lc''] [lw] [Hci] [Hw] -> /=. move: lsem_add_align. move=> Ha.
        move: (Ha gd s1 
              (ι (Lilabel lbl) :: lc ++ [:: ι (Licond e lbl)]) ii a).
        move=> {Ha} Ha.
        (* we need to resolve a due to the way lsem_add_align is structured *)
        case: a Ha Hw=> /= Ha Hw //=.
        (* a = Align *)
        * move: (Ha s2). move=> {Ha} Ha. 
          move: (Ha [:: Lempty
           & leak_i_iLs leak_i_iL stk ltc lc' ++
           Lcondl le true :: ilwhile_c'0 leak_i_iL stk ltc lw]). 
         rewrite /=. move=> {Ha} Ha. apply Ha.
          apply: lsem_step=> //. move=> {Ha}.
          set L := [:: ι (Lilabel lbl) ].
          set C := L ++ lc ++ [:: ι (Licond e lbl)].
          have HL : valid lbl (next_lbl lbl) L by rewrite/L/= Pos.leb_refl ltL1.
          have Hd : disjoint_lbl L lc by apply: valid_disjoint _ HL Hvc; 
          by rewrite Pos.leb_refl.
          move: (Hc s1 si lc' H). move=> /= Hc'.
          apply: tc_trans.
          have /(_ _ Hd) := lsem_cat_hd _ Hc'. move=> Hhd.
          rewrite /lsem in Hhd.
          ** rewrite /setpc /=.           
             move: (lsem_cat_tl [:: ι (Licond e lbl)]).
             move=> Htl. rewrite /lsem in Hhd. rewrite /lsem in Htl.
             move: (Htl gd (add_hd_c L (of_estate s1 lc 0))
                        (add_hd_c L (of_estate si lc (size lc)))
                        (leak_i_iLs leak_i_iL stk ltc lc') Hhd).
            rewrite /= /setc /add_hd_c /=. move=> {Htl} Htl. apply Htl.
          ** apply: lsem_step => //.
             *** rewrite /lsem1 /step /= /of_estate /find_instr /=.
                 rewrite onth_cat ltnn subnn /= /eval_instr /=. 
                 by rewrite to_of_estate He /= /setpc /= find_label_hd /=.
             *** admit. (* recursive part *)    
        (* a = NoAlign *)
        * move: (Ha s2). move=> {Ha} Ha. 
          move: (Ha ([:: Lempty] ++ [:: Lempty] ++ leak_i_iLs leak_i_iL stk ltc lc' 
                     ++ Lcondl le true :: ilwhile_c'0 leak_i_iL stk ltc lw)). 
          rewrite /=. move=> {Ha} Ha. 
          apply Ha. 
          apply: lsem_step=> //. move=> {Ha}. exists (setpc (of_estate s1 (ι (Lilabel lbl) :: lc ++ [:: ι (Licond e lbl)]) 0)
         (lpc (of_estate s1 (ι (Lilabel lbl) :: lc ++ [:: ι (Licond e lbl)]) 0)).+1).
          ** rewrite /lsem1. admit.
          ** apply: tc_trans.
             set L := [:: ι (Lilabel lbl) ].
             set C := L ++ lc ++ [:: ι (Licond e lbl)].
             have HL : valid lbl (next_lbl lbl) L by rewrite/L/= Pos.leb_refl ltL1.
             have Hd : disjoint_lbl L lc by apply: valid_disjoint _ HL Hvc; 
             by rewrite Pos.leb_refl.
             move: (Hc s1 si lc' H). move=> /= Hc'.
             have /(_ _ Hd) := lsem_cat_hd _ Hc'. move=> Hhd.
             rewrite /lsem in Hhd.
             move: (lsem_cat_tl [:: ι (Licond e lbl)]).
             move=> Htl. rewrite /lsem in Hhd. rewrite /lsem in Htl.
             move: (Htl gd (add_hd_c L (of_estate s1 lc 0))
                        (add_hd_c L (of_estate si lc (size lc)))
                        (leak_i_iLs leak_i_iL stk ltc lc') Hhd).
            rewrite /= /setc /add_hd_c /=. move=> {Htl} Htl. apply Htl.
            apply: lsem_step=> //.
            rewrite /lsem1 /step /= /of_estate /find_instr /=.
            rewrite onth_cat ltnn subnn /= /eval_instr /=. 
            by rewrite to_of_estate He /= /setpc find_label_hd /=. 
            admit. (* recursive [art *)
      (* b is false *)
      - move=> He [] <- -> /=. move: lsem_add_align. move=> Ha.
        move: (Ha gd s1 
              (ι (Lilabel lbl) :: lc ++ [:: ι (Licond e lbl)]) ii a).
        move=> {Ha} Ha.
        (* we need to resolve a due to the way lsem_add_align is structured *)
        case: a Ha=> /= Ha.
        (* a = Align *)
        * move: (Ha si). move=> {Ha} Ha. 
          move: (Ha ([:: Lempty] ++ leak_i_iLs leak_i_iL stk ltc lc' ++ 
          [:: Lcondl le false])). rewrite /=. move=> {Ha} Ha. apply Ha.
          apply: lsem_step=> //. move=> {Ha}.
          set L := [:: ι (Lilabel lbl) ].
          set C := L ++ lc ++ [:: ι (Licond e lbl)].
          have HL : valid lbl (next_lbl lbl) L by rewrite/L/= Pos.leb_refl ltL1.
          have Hd : disjoint_lbl L lc by apply: valid_disjoint _ HL Hvc; 
          by rewrite Pos.leb_refl.
          move: (Hc s1 si lc' H). move=> /= Hc'.
          apply: tc_trans.
          have /(_ _ Hd) := lsem_cat_hd _ Hc'. move=> Hhd.
          rewrite /lsem in Hhd.
          ** rewrite /setpc /=.           
             move: (lsem_cat_tl [:: ι (Licond e lbl)]).
             move=> Htl. rewrite /lsem in Hhd. rewrite /lsem in Htl.
             move: (Htl gd (add_hd_c L (of_estate s1 lc 0))
                        (add_hd_c L (of_estate si lc (size lc)))
                        (leak_i_iLs leak_i_iL stk ltc lc') Hhd).
            rewrite /= /setc /add_hd_c /=. move=> {Htl} Htl. apply Htl.
          ** apply: tc_step.
             rewrite /lsem1 /step /= /of_estate /find_instr /=.
             rewrite onth_cat ltnn subnn /= /eval_instr /=. 
             rewrite to_of_estate He /= /setpc /= size_cat /=.
             admit. (* need to apply symmetry *)
        (* a = NoAlign *)
        * move: (Ha si). move=> {Ha} Ha. 
          move: (Ha ([:: Lempty] ++ [:: Lempty] ++ leak_i_iLs leak_i_iL stk ltc lc' ++ 
          [:: Lcondl le false])). rewrite /=. move=> {Ha} Ha. apply Ha. 
          apply: lsem_step=> //. move=> {Ha}. exists (setpc (of_estate s1 (ι (Lilabel lbl) :: lc ++ [:: ι (Licond e lbl)]) 0)
         (lpc (of_estate s1 (ι (Lilabel lbl) :: lc ++ [:: ι (Licond e lbl)]) 0)).+1).
          ** rewrite /lsem1. admit.
          ** apply: tc_trans.
             set L := [:: ι (Lilabel lbl) ].
             set C := L ++ lc ++ [:: ι (Licond e lbl)].
             have HL : valid lbl (next_lbl lbl) L by rewrite/L/= Pos.leb_refl ltL1.
             have Hd : disjoint_lbl L lc by apply: valid_disjoint _ HL Hvc; 
             by rewrite Pos.leb_refl.
             move: (Hc s1 si lc' H). move=> /= Hc'.
             have /(_ _ Hd) := lsem_cat_hd _ Hc'. move=> Hhd.
             rewrite /lsem in Hhd.
             move: (lsem_cat_tl [:: ι (Licond e lbl)]).
             move=> Htl. rewrite /lsem in Hhd. rewrite /lsem in Htl.
             move: (Htl gd (add_hd_c L (of_estate s1 lc 0))
                        (add_hd_c L (of_estate si lc (size lc)))
                        (leak_i_iLs leak_i_iL stk ltc lc') Hhd).
            rewrite /= /setc /add_hd_c /=. move=> {Htl} Htl. apply Htl.
            apply: tc_step.
            rewrite /lsem1 /step /= /of_estate /find_instr /=.
            rewrite onth_cat ltnn subnn /= /eval_instr /=. 
            rewrite to_of_estate He /= /setpc /= size_cat /=.
            admit. (* need to apply symmetry *)
    (* last case *)
    move: (i :: c') => { i c' } c' Hc'.
    rewrite linear_c_nil;case Heqc: linear_c => [[[lblc lc] ltc]|] //=.
    have {Hc}[Hle1 Hvc Hc]:= Hc _ _ _ _ Heqc.
    rewrite linear_c_nil.
    case Heq:linear_c => [[[lblc' lc'] ltc']|] //= [] ???;subst lbli li lti.
    have leL1 := le_next lbl; have leL2 := le_next (next_lbl lbl).
    have lblL2 := Pos_leb_trans leL1 leL2.
    have lblcL2 := Pos_leb_trans lblL2 Hle1.
    have {Heq} [Hle Hv Hs]:= Hc' _ _ _ _ Heq;split.
    + apply: (Pos_leb_trans lblL2).
      by apply: (Pos_leb_trans Hle1).
    + rewrite /= valid_add_align /= valid_cat /= Pos.leb_refl leL1 (valid_le_min _ Hv) //.
      rewrite (Pos_lt_leb_trans (lt_next _)).
      rewrite (Pos_lt_leb_trans _ Hle) /=.
      rewrite valid_cat /= leL1 /=.
      rewrite (valid_le_max Hle) /=.
      rewrite (Pos_lt_leb_trans (lt_next _)) //.
      rewrite (Pos_leb_trans Hle1) //.
      rewrite (valid_le_min _ Hvc) //.
      rewrite (Pos_lt_leb_trans (lt_next _)) //.
      rewrite (Pos_leb_trans _ Hle) //.
      rewrite (Pos_leb_trans leL2 Hle1) //.
    move=> s1 s2 l H.
    set C := (C in of_estate _ C _);rewrite -/C.
    move: H. move=> /S.sem_iE'. move=>  [si] [b] [lc0] [le] [H] [He].
    case: b He=> //=. 
    (* subcase: b = true *)
    + move=> He [sj] [lc'0] [lw] [H'] [Hw'] -> /=.
      apply lsem_step with (of_estate s1 C ((a == Align) + (size lc').+2).+1).
      * rewrite /lsem1 /step /= /eval_instr /=.
        have -> // : find_label lbl C =  ok ((a == Align) + (size lc').+2).
        rewrite /C -cat1s find_label_cat_hd // find_label_add_align.
        rewrite -!cat_cons find_label_cat_hd /=.
        ** by rewrite find_label_hd /= addn0 addnA (addnC 1) -addnA.
        ** rewrite /= {1}/is_label /=.
           case: eqP => H'' /=.
           + by have := lt_next lbl; rewrite Pos.ltb_antisym -H'' Pos.leb_refl.
      apply /negP=> H1;have := @valid_has _ lbl _ _ Hv.
      rewrite H1 Pos.leb_antisym.
      by rewrite (Pos_lt_leb_trans (Pos_lt_leb_trans (lt_next _) leL2) Hle1) /= => /(_ isT).

    (* Start induction after the first goto (at the first location where the loop will come back) *)
    pose C1 := (ι (Lilabel (next_lbl lbl)) :: lc' ++ ι (Lilabel lbl) :: lc ++ 
                  [:: ι (Licond e (next_lbl lbl))]).
    have : lsem gd (of_estate s1 C1 ((size lc').+2)) 
                (leak_i_iLs leak_i_iL stk ltc lc0 ++
                            Lcondl le true
                            :: leak_i_iLs leak_i_iL stk ltc' lc'0 ++
        Lempty :: ilwhile leak_i_iL stk ltc ltc' lw) (of_estate s2 C1 (size C1))
            ;last first.
    + rewrite /C add_align_nil -cat_cons size_cat => h.
      have -> : ((a == Align) + (size lc').+2).+1 =
                size ((ι (Ligoto lbl) :: add_align ii a [::])) + (size lc').+2.
      + by case: (a).
      (*by apply: (lsem_cat_hd _ h); rewrite /disjoint_lbl; case:(a).
    elim: _ {-1}_ _ / H Hs (erefl (Cwhile a c e c'))=> // {s1 s2}.
    + move=> s1 s2 s3 s4 a0 c0 e0 c'0 Hsem0 He Hsem Hsemi IH Hs [] ????; subst a0 c0 e0 c'0.
      apply (@lsem_trans gd (of_estate s2 C1 ( (size lc').+2 + size lc))).
      + have Hd: disjoint_lbl
          [:: {| li_ii := ii; li_i := Llabel (next_lbl lbl) |}
          & lc' ++ [:: {| li_ii := ii; li_i := Llabel lbl |}]] lc.
        + rewrite -cat1s !disjoint_cat_l; repeat split=> //.
          + move=> lbl0 /=;rewrite orbF /is_label /=; case: eqP=> //= ?;subst.
            apply /negP=> H; have := @valid_has _ (next_lbl lbl) _ _ Hvc.
            by rewrite H Pos.leb_antisym (lt_next _) orbT=> /(_ isT).
          + apply: (valid_disjoint _ Hv Hvc).
            by rewrite Pos.leb_refl /= orbT.
          + move=> lbl0 /=; rewrite orbF /is_label /=; case: eqP=> //= ?;subst.
            apply/negP=> H; have := @valid_has _ lbl _ _ Hvc.
            by rewrite H Pos.leb_antisym (Pos_lt_leb_trans (lt_next _) leL2) orbT=> /(_ isT).
        have /(_ _ Hd):= lsem_cat_hd _ (Hc _ _ Hsem0).
        move=> /(lsem_cat_tl [:: MkLI ii (Lcond e (next_lbl lbl))]) /=.
        rewrite !of_estate_add_hd_c !setc_of_estate /= /C1.
        by rewrite !size_cat addn0 /= addn1 !addSn /= -!cat_cons -!catA.
      apply: lsem_step.
      + rewrite /lsem1 /step /= /C1 /find_instr /=.
        rewrite -cat_cons catA onth_cat size_cat /= addnS ltnn subnn /eval_instr /=.
        rewrite to_of_estate He /find_label /= /is_label /= eqxx /=;eauto.
      rewrite setpc_of_estate.
      apply: lsem_trans.
      + have Hd : disjoint_lbl [:: MkLI ii (Llabel (next_lbl lbl))] lc'.
        + move=> lbl0 /=;rewrite orbF /is_label /=;case: eqP => //= ?;subst.
          apply /negP=> H;have := @valid_has _ (next_lbl lbl) _ _ Hv.
          rewrite H Pos.leb_antisym.
          by rewrite (Pos_lt_leb_trans (lt_next _) Hle1) /= orbT => /(_ isT).
      have /(_ _ Hd) := lsem_cat_hd _ (Hs _ _ Hsem).
      move=> /(@lsem_cat_tl ((MkLI ii (Llabel lbl)) :: lc ++ [:: MkLI ii (Lcond e (next_lbl lbl))])).
      rewrite !of_estate_add_hd_c !setc_of_estate !lc_of_estate addn0.
      rewrite -!cat_cons -!catA => H.
      apply: (lsem_trans H);apply: LSem_step.
      + by rewrite /lsem1 /step /= /find_instr /= onth_cat ltnn subnn /= /eval_instr /=;eauto.
      exact: IH.
    + move=> s1 s2 c0 a0 e0 c0' Hs0 He Hs [????]; subst a0 e0 c0 c0'.
      apply (@lsem_trans gd (of_estate s2 C1 (size lc' + size lc).+2)).
      + have Hd: disjoint_lbl
          [:: {| li_ii := ii; li_i := Llabel (next_lbl lbl) |}
          & lc' ++ [:: {| li_ii := ii; li_i := Llabel lbl |}]] lc.
          rewrite -cat1s !disjoint_cat_l; repeat split=> //.
          + move=> lbl0 /=;rewrite orbF /is_label /=; case: eqP=> //= ?;subst.
            apply /negP=> H; have := @valid_has _ (next_lbl lbl) _ _ Hvc.
            by rewrite H Pos.leb_antisym (lt_next _) orbT=> /(_ isT).
          + apply: (valid_disjoint _ Hv Hvc).
            by rewrite Pos.leb_refl /= orbT.
          + move=> lbl0 /=; rewrite orbF /is_label /=; case: eqP=> //= ?;subst.
            apply/negP=> H; have := @valid_has _ lbl _ _ Hvc.
            by rewrite H Pos.leb_antisym (Pos_lt_leb_trans (lt_next _) leL2) orbT=> /(_ isT).
        have /(_ _ Hd) := lsem_cat_hd _ (Hc _ _ Hs0).
        move=> /(lsem_cat_tl [:: MkLI ii (Lcond e (next_lbl lbl))]) /=.
        rewrite !of_estate_add_hd_c !setc_of_estate /= size_cat /= addn0 addn1.
        by rewrite -!cat_cons -!catA.
      apply: lsem_step.
      + rewrite /lsem1 /step /find_instr /= -cat_cons catA onth_cat.
        by rewrite size_cat /= addnS ltnn subnn /eval_instr /= to_of_estate He /=;eauto.
      rewrite setpc_of_estate /C /= size_cat /= size_cat /= addn1 !addnS.
      exact: rt_refl.
  Qed.
*)
  admit. admit.
  (* b = false *)
  admit.
  Admitted.

  Let Hcall : forall i xs f es, Pi_r (Ccall i xs f es).
  Proof. by []. Qed.

  Lemma linear_cP c lbl lblc lc ltc:
    linear_c linear_i c lbl [::] = ok (lblc, lc, ltc) ->
    [/\ (lbl <=? lblc)%positive,
     valid lbl lblc lc &
     forall s1 s2 l, S.sem p gd s1 c l s2 ->
       lsem gd (of_estate s1 lc 0) (leak_i_iLs (leak_i_iL) stk ltc l)
 (of_estate s2 lc (size lc))].
  Proof.
    apply (@cmd_rect Pi_r Pi Pc HmkI Hskip Hseq Hassgn Hopn Hif Hfor Hwhile' Hcall).
  Qed.

  Lemma linear_fdP:
    forall fn m1 va m2 vr lf,
    S.sem_call p gd m1 fn va (fn, lf) m2 vr -> 
    lsem_fd p' gd m1 fn va (fn, leak_i_iLs leak_i_iL stk (leak_Fun_L Fs fn) lf) m2 vr.
  Proof.
    move=> fn m1 vargs m2 vargs' lf /S.sem_callE' [] sf [] Hsf [] m1' [] m2' [] vargs1 [] s2 [] m2'' [] vm2 [] vres.
    move=> [] Halloc [] Hs1 [] Htyi [] Hs2 [] /= Hbody [] Hres [] Htyo Hm2.
    have dcok : map_cfprog_leak linear_fd p = ok (p', Fs).
    + move: linear_ok; rewrite /linear_prog /=. by move=> ->.
    have := (get_map_cfprog_leak dcok Hsf). move=> [] f' [] lt' [] Hf'1 /= Hf'2 Hleak.
    have Hf'3 := Hf'1.
    apply: rbindP Hf'3=> [[[l1 l2] l3] Hc] [] Hf'3.
    rewrite /add_finfo in Hc.
    case Heq: linear_c Hc=> [[[lblc lc'] ltc]|] //= [] Hl Hl1 Hl2 Hl3.
    rewrite linear_c_nil in Heq.
    apply: rbindP Heq=> [[[lblc' lc''] ltc']] Heq [] Hz1 Hz2.
    have [h1 h2 H]:= linear_cP Heq.
    move: Hbody=> /H /(@lsem_cat_tl [::]) Hs.
    rewrite -Hf'3 in Hf'2. move=> h.
    eapply LSem_fd; eauto.
    rewrite /=. rewrite -Hl2 in Hl3. rewrite h in Hs. rewrite Hl3 in Hs.
    move: Hs; rewrite /= Hz2 !setc_of_estate.
    have -> // : size lc'' = size lc'.
    by rewrite -Hz2 size_cat addn0.
    rewrite /of_estate /=. 
    have hf : (leak_Fun_L Fs fn) = lt'.
    + rewrite /get_leak in Hleak. rewrite /leak_Fun_L /=. by rewrite Hleak.
    move=> hs. rewrite hf. rewrite -Hl1. apply hs.
  Qed.

End PROOF.

