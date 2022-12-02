(* Copyright: Amba Kulkarni (2014-2022)                             *)
(* Indian Institute of Advanced Study, Shimla (Nov 2015 - Oct 2017)             *)

(* To add: gam1 can not have both karma and aXikaraNa *)
open Hashtbl;
open Pada_structure;

open Bank_lexer;
module Gram=Camlp4.PreCast.MakeGram Bank_lexer
;
open Bank_lexer.Token
;
(*value relations=Gram.Entry.mk "relations"
;
*)
value multiple_relations_begin=21 (* inclusive *)
(* Two or more aXikaraNa, kAla-aXikaraNa, xeSa-aXikaraNa, pUrvaAlaH, ... are possible 
Ex: ekaxA yaxA .. waxA *)
;
value multiple_relations_end=41 (* inclusive *)
;
value max_rels=300 (* Max relations in a sentence *)
;
value compatible_relations=Array.make max_rels []
;
value compatible_words=Array.make max_rels []
;
value compatible_all_words=Array.make max_rels False
;
value inout_rels=Array.make max_rels 0
;
value total_dags_so_far=ref 1
;
(* Grammar of morph_analyses coming from sentence *)
(*
EXTEND Gram
  GLOBAL: relations;
  relations:
    [ [ l=rel_rec; `EOI -> l
      | l=rel_rec -> failwith "Wrong relation data"
    ] ] ;
  rel_rec:
    [ [ -> []
      | l=rel_rec; t=relationc ->  (* left (terminal) recursion essential *)
  l @ [ t ]
    ] ] ;
  relationc:
    [ [ r=relc -> Relationc r
    ] ] ;

  relc:
    [ [  i1=INT;
   m1=INT;
   rel=INT;
   i2=INT;
   m2=INT ->
  (int_of_string i1,int_of_string m1,int_of_string rel,int_of_string i2,int_of_string m2)
    ] ] ;

END
;
*)
(* value analyse strm=let relations =
  try Gram.parse relations Loc.ghost strm with
  [ Loc.Exc_located loc (Error.E msg) -> do
     { output_string stdout "\n\n"
     ; flush stdout
     ; Format.eprintf "Lexical error: %a in line %a in example \n%!"
                      Error.print msg Loc.print loc
     ; failwith "Parsing aborted\n"
     }
  | Loc.Exc_located loc (Stream.Error msg) -> do
     { output_string stdout "\n\n"
     ; flush stdout
     ; Format.eprintf "Syntax error: %s in example \n%!" msg
     ; failwith "Parsing aborted\n"
     }
  | Loc.Exc_located loc ex -> do
     { output_string stdout "\n"
     ; flush stdout
     ; Format.eprintf "Fatal error in example \n%!"
     ; raise ex
     }
  | ex -> raise ex
  ]  in relations
;
*)

(*
   Input: A Graph represented as a list of edges (relations) represented
          as quintuples (id1,mid1,rel,id2,mid2), where 'rel' is the label
          on the edge from the node 'id2,mid2' to the node 'id1,mid1'.
   Output: Labeled, directed acyclic graphs (DAGS) ordered on cost, satisfying
           the constraints, where a DAG is a set of compatible edges.

   Constraints are described in chk_compatible function.
   Cost function is defined in add_cost.

   1. Relations are indexed starting from 1
   2. For each relation a list of compatible_relations is populated
      compatible_relations.(i) contains the indices of all the relations, from i+1 onwards that are compatible with relation i.
   3. We split the words into two halves, and build all possible dags for each of the havles, and then join the dags so constructed 
      by checking the compatibility.
*)

value intersection l1 l2=if List.length l1 < List.length l2 
                           then List.filter (fun x -> (List.mem x l1)) l2
                           else List.filter (fun x -> (List.mem x l2)) l1 (* l1 intersection l2 *)
;

value print_relation r=match r with
 [ Relationc (i1,i2,i3,i4,i5)   -> do
    { print_string "("
    ; print_int (i1-1); print_string ","
    ; print_int (i2-1); print_string ","
    ; if (i3 >= 2000) then print_int (i3 - (i3 mod 100)) 
      else if (i3=1009) then print_int 9 
      else if (i3=1079) then print_int 79 
      else if (i3=70) then print_int 34  (* hewuH -> hewu *)
      else if (i3=33) then print_int 32  (* aBexaH -> viSeRaNam *)
      else if (i3=61) then print_int 60  (* sup_samucciwaH -> samucciwaH *)
      else if (i3=63) then print_int 62  (* sup_anyawaraH -> anyawaraH *)
      else if (i3=65) then print_int 64  (* sup_samucciwa_xyowakaH -> samucciwa_xyowakaH *)
      else if (i3=67) then print_int 66  (* sup_anyawara_xyowakaH -> anyawara_xyowakaH *)
      else if (i3=6) then print_int 7  (* karwA_be_verb -> karwA*)
      else if (i3=8) then print_int 9  (* karwqrahiwakarwqsamAnAXikaraNa -> viXeya_viSeRaNam *)
      (* else if (i3=64) || (i3=65) (* samuccayaxyowaka,sup_samuccayaxyowaka *)
      then print_int 1
      else if (i3=66) || (i3=67) (* anyawaraxyowaka,sup_anyawaraxyowaka *)
      then print_int 1 *)
      else print_int i3
    ; print_string ","
    ; print_int (i4-1); print_string ","
    ; print_int (i5-1); print_string ")\n"
    }
 ]
;

value print_relation_in_dag relations r=
	let rel=List.nth relations (r-1) in
	print_relation rel
;

value join_relations a b c d e u v w x y =
    if d=u && e=v 
    then if c >= 2000 && c < 2100
      then if w >= 4000 && w < 4100 then [Relationc (a,b,42,d,e);Relationc (u,v,20,x,y)]
      else if w >= 4100 && w < 4200 then [Relationc (a,b,42,d,e); Relationc (u,v,21,x,y)]
      else if w >= 4200 && w < 4300 then [Relationc (a,b,42,d,e); Relationc (u,v,7,x,y)] 
      else if w >= 4300 && w < 4400 then [Relationc (a,b,42,d,e); Relationc (u,v,28,x,y)] 
      else if w >= 4400 && w < 4500 then [Relationc (a,b,42,d,e); Relationc (u,v,9,x,y)] 
      else if w >= 4500 && w < 4600 then [Relationc (a,b,42,d,e); Relationc (u,v,25,x,y)] 
      else if w=21 && c >= 2000 && c < 2100 then [Relationc (a,b,42,d,e)] 
      else []
    (* else if c >= 2100 && c < 2200 then [Relationc (u,v,21,x,y)]  *)
    else if c >= 2200 && c < 2300 then [Relationc (u,v,14,x,y)] 
    else if c >= 2400 && c < 2500 && w >= 4300 && w < 4400 then [
            Relationc (u,v,95,x,y); Relationc(a,b,42,d,e)] 
    else if c >= 2600 && c < 2700 then [Relationc (u,v,49,x,y)] 
    (* else if c >= 2700 && c < 2800 then [Relationc (u,v,14,x,y)]  *)
    (*else if c >= 3100 && c < 3200  && w >= 4300 && w < 4400 then [Relationc (a,b,c,d,e);Relationc (u,v,92,x,y)]*)
    else if c >= 3200 && c < 3300  && w >= 4300 && w < 4400 then [Relationc (a,b,c,d,e);Relationc (u,v,93,x,y)] 
    else if c >= 2300 && c < 2400 && w >= 4300 && w < 4400 
    then [Relationc (a,b,c,d,e);Relationc (u,v,w,x,y)] 
    else if c >= 2900 && c < 3000 && w >= 4300 && w < 4400 
    then [Relationc (u,v,94,x,y)] 
    else []
    else []
;

value collapse_upapada_relations relations part_dag a b c d e=
    loop [] relations part_dag
    where rec loop acc relations=fun
    [ [] -> acc (* if (c >=2000 && c < 2300) || (c >= 2400 && c < 4000) 
(*(c >= 2400)*)
            then if not (acc=[])
            then List.append acc [Relationc (a,b,0,d,e)] 
            else []
            (*else [Relationc (a,b,c,d,e)] *)
(* We need to handle karma pravacanIya separately *)
            else if (c >= 2300 && c < 2400)
            then acc
            else [] *)
    | [r :: l ] -> let rel=List.nth relations (r-1) in
            match rel with
            [Relationc (u,v,w,x,y) -> 
                    let acc1 =
                    if c >= 2000 && c < 4000 && w >= 4000
                    then join_relations a b c d e u v w x y
                    else if c >= 4000 && w >= 2000 && w < 4000
                    then join_relations u v w x y a b c d e 
                    else if c >= 2000 &&  c < 2100 && w=21
                    then join_relations a b c d e u v w x y
                    else if c=21 && w >= 2000  && w < 2100
                    then join_relations u v w x y a b c d e
                    else []
                in  let acc2=if acc1=[] then []
                    (*else if ((c >= 3100 && c < 3300)) -- removed, since now upa_vinA and upa_saha relations are being marked from translation point of view.
                     * Earlier we would group them together with the previous wqwIyA viBakwi word
                    (* else if ((c >= 2000 && c < 2300) || (c >=2400 && c < 4000)) *)
                    then List.append acc1 [Relationc (a,b,0,d,e)]  *)
                     (* for saha and vinA grouping *)
                    (*else if (c >=4000)
                    then List.append acc1 [Relationc (u,v,0,x,y)] *)
		    else acc1
                in let acc3=List.append acc acc2 
                in  loop acc3 relations l
            ]
    ]
; 

value lwg_and_collapse relations dag =
    loop [] relations dag
    where rec loop acc relations=fun
    [ [] -> acc
    | [r :: l ] ->
           let rel=List.nth relations (r-1) in
            match rel with
            [Relationc (a,b,c,d,e) -> 
               if c < 2000
               then let acc1=if c=91  (* avaXiH  not defined in build_graph.ml! *)
                               then List.append acc [Relationc (a,b,0,d,e)] 
                               else if c =214
                               then List.append acc [Relationc (a,b,14,d,e)] 
                               else if (c=200) (*gawikarwA -> karwA *)
                               then List.append acc [Relationc (a,b,7,d,e)] 
                               else if (c=201) (*gawikarma -> karma *)
                               then List.append acc [Relationc (a,b,14,d,e)] 
                               else List.append acc [rel] 
                    in loop acc1 relations l
               else let acc1=
                    collapse_upapada_relations relations l a b c d e
                    in let acc2=List.append acc acc1
                    in loop acc2 relations l
            ]
    ]
;


value print_cost_soln (len,c,l) n count rel=do
        { (*print_string "len="; print_int len; *)
          if len > count then 
          do { print_string "Solution:"
            ; print_int n; print_newline ()
            ; List.iter print_relation l
            ; print_string "Cost="; print_int c
            ; print_string "\n\n"
            }
    else ()
}
;

  (*expects (int,int,int list) list *)
value rec print_cost_soln_list n count rel=fun
  [ [] -> ()
  | [ (len,a,l) :: r ] -> do
          { (*print_string "n="; print_int n; print_newline()
      ; *)print_cost_soln (len,a,l) n count rel
      ; print_cost_soln_list (n+1) count rel r
      }
  ]
;

value between b a c =
  if (a < b && b < c) || (c < b && b < a) then True else False
;

value single_morph_per_word m1 m2=match m1 with
    [ Relationc (to_id1,to_mid1,r1,from_id1,from_mid1) -> match m2 with
      [Relationc (to_id2,to_mid2,r2,from_id2,from_mid2) -> 
            (* Two morph analyses for a word *)

         if (to_id1=to_id2) && not (to_mid1=to_mid2) then False (* do { print_string "C1"; False} *)
         else if (to_id1=from_id2) && not (to_mid1=from_mid2) then False (* do { print_string "C2"; False} *)
         else if (from_id1=from_id2) && not (from_mid1=from_mid2) then False (* do { print_string "C3"; False} *)
         else if (from_id1=to_id2) && not (from_mid1=to_mid2) then False (* do { print_string "C4"; False} *)
         else True
      ]
    ]
;

value single_relation_label m1 m2= match m1 with
    [ Relationc (to_id1,to_mid1,r1,from_id1,from_mid1) -> match m2 with
      [Relationc (to_id2,to_mid2,r2,from_id2,from_mid2) -> 
            (* Two incoming arrows (*with diff labels*) except niwya_sambanXaH (=101, & 102) *)
         if (to_id1=to_id2) && (to_mid1=to_mid2) (*&& not (r1=r2) *)
         && not (r1=101) && not(r2=102) 
         && not (r1=102) && not(r2=101) 
         then False  (*do { print_string "C5"; False}*)
            (* Two outgoing arrows with same label *)
         else if (from_id1=from_id2) && (from_mid1=from_mid2) && (r1=r2)
              && ( (r1 < multiple_relations_begin  && not (r1=101))
                  || (r1 > multiple_relations_end && not (r1=102) && not (r1=60) && not (r1=61) && not (r1=62) && not (r1=63))
                  ) (* niwya sambanXaH (=101,102)*)
         then False (*do { print_string "C9"; False}*)
            (* there can not be another outgoing rel with an upapaxa sambanXa*)
         else if (from_id1=from_id2) && (from_mid1=from_mid2) && ((r1 >= 2000  && r1 < 4000) || (r2 >= 2000 && r2 < 4000)) 
         then False  (*do { print_string "C9"; print_int r1; print_int r2;False} *)
         else if  (from_id1=to_id2) && (from_mid1=to_mid2) 
               && r1=82 (*vIpsA*) && (r2=101 || r2=102)
              then False  (*do { print_string "C10"; False} *)
         else True  (*do {print_string "C11"; True}*)
      ]
    ]
;

value no_crossing text_type rel m1 m2=match m1 with
    [ Relationc (to_id1,to_mid1,r1,from_id1,from_mid1) -> match m2 with
      [Relationc (to_id2,to_mid2,r2,from_id2,from_mid2) -> 
           (* Crossing edges not allowed except niwya_sambanXaH (=101,102) and samucciwa (=53) , upamAnaxyowakaH (=80) in some cases*)
           (* Crossing edges allowed even with RaRTI(=35), ViSeRaNa(=32) and aBexaH (=33) *)
         if  (   (    between to_id1 to_id2 from_id2
                   || between from_id1 to_id2 from_id2
                 )
              && (    between to_id2 to_id1 from_id1
                   || between from_id2 to_id1 from_id1
                 )
             )
         (* sup_samucciwaH=61 removed from the following list. It overgenerates.
          * We need at least one example to retain it *)
             && not (r1=101 || r1=102 || r1=22 || r1=47 || r1=29 || r1=30)
             && not (r2=101 || r2=102 || r2=22 || r2=47 || r2=29 || r2=30)
             && (((not ((r1=32) || (r1=33) || (r1=35) || (r1=80) || (r1=9) ||
                     (r2=32) || (r2=33) || (r2=35) || (r2=80) || (r2=9)))
                    && text_type="Sloka")
                 || (text_type="Prose" && not (r1=9 || r2=9)))
             (* removed RaRTI, viSeRaNa, aBexa, temporarily *)
         then False else True
             (* let length=List.length rel -1 in
              loop False 0 
              where rec loop acc j=
              if j > length then acc else
               match List.nth rel j with
               [ Relationc (id1,mid1,r,id2,mid2)  ->
                  if (r=32) &&
                   ((id1=to_id1 && mid1=to_mid1 && id2=from_id2 && mid2=from_mid2) ||
                   (id1=from_id2 && mid1=from_mid2 && id2=to_id1 && mid2=to_mid1) ||
                   (id1=to_id2 && mid1=to_mid2 && id2=from_id1 && mid2=from_mid1) ||
                   (id1=from_id1 && mid1=from_mid1 && id2=to_id2 && mid2=to_mid2))
                  then loop True (length+1) 
                  else loop False (j+1) 
               | _  ->  True
               ] 
         else True  *)
      ]
    ]
;

value same_root from_id1 from_id2 from_mid1 from_mid2 =
         if (from_id1=from_id2) && (from_mid1=from_mid2) then True else False

;

value outgoing_incompatible_rels rpair = match rpair with
   [(200,201) (* There can not be both gawi karma and gawi karwA simultaneously *)
   |(201,200) 
   |(13,14) (* If there is a vAkyakarma, then there can not be a karma  but there can be gONa / muKya karma*)
   |(14,13)
  (* |(13,12)
   |(13,11) *)
  (* |(11,13)
   |(12,13) *)
   |(14,11)  (* If there is a karma, then there can not be a gONa or muKyakarma *)
   |(14,12)
   |(11,14)
   |(12,14)
   |(15,7) (* If there is a karwA there cannot be a prayojaka karwA simultaneously *)
   |(16,7)
   |(7,15)
   |(7,16)
   |(214,11) (* If there is a iRkarma, there can not be karma, gONakarma, muKyakarma *)
   |(214,12)
   |(214,14)
   |(11,214)
   |(12,214)
   |(14,214)
   |(12,19)      (* In the case of brU, occasionally sampraxAna is also allowed.  * But then there can not be a gONa karma * ex: BhG we wAna bravImi BHg 1.7 *)
   |(19,12)
   |(7,8)     (* With karwqrahiwaviXeya_viSeRaNam there can not be karwA *)
   |(8,7) 
   |(10,12)   (* With karmasamAnAXikaraNa there can not be gONa-karma 
               * brU1 and vax1 dhaatus are xvikarmaka, and if there is karmasamaanaadhikarana relation with them, then gONa karma should be absent *)
   |(12,10) -> False
   |(_,_) -> True
   ]
 ; 

 value sequence from_id from_mid to_id to_mid =
       from_id=to_id && from_mid=to_mid
;

value not_allowed_sequence_rels rpair = match rpair with
  [ (* a RaRTI/prawiReXaH of a kriyAviSeRaNa or a viSeRaNa is not allowed ; removed aBexa; RaRTI of aBexa is allowed; SriyaH pawiH*)
  (26,35)
  |(26,49)
  |(32,35)
  |(32,49)
  |(35,26)
  |(49,26)
  (*|(35,32) -- removed, since viSeRaNa of RaRTI is possible as in vIrasya rAmasya puwraH *)
  |(49,32)
   (* a viSeRaNa of a viSeRaNa is not allowed *)
  |(32,9)
  |(32,32)
  |(9,32)
  |(9,9)
 (* an aBexa of an aBexa is not allowed *)
  |(33,33)
 (* a viSeRaNa of an aBexa is not allowed *)
  |(33,32)
  |(32,33)
  |(33,9)
  |(9,33)
 (* samucciwa of samucciwa is not allowed *)
  |(60,60)
  |(61,61)
  |(62,62)
  |(63,63)
(* karwA / karma of a karmasamAnAXikaraNam not allowed *)
  |(10,7)
  |(10,11)
  |(10,12)
  |(10,14)
  |(7,10)
  |(11,10)
  |(12,10)
  |(14,10)
(* karwA / karma of a samAnAXikaraNam not allowed *)
  |(1009,7)
  |(1009,11)
  |(1009,12)
  |(1009,14)
  |(7,1009)
  |(11,1009)
  |(12,1009)
  |(14,1009)
  |(9,7)
  |(9,11)
  |(9,12)
  |(9,14)
  |(7,9)
  |(11,9)
  |(12,9)
  |(14,9)
(* viXeya_viSeRaNam/samAnAXikaraNam of a viXeya_viSeRaNam/samAnAXikaraNam not allowed *)
  |(9,1009)
  |(1009,1009)
  |(1009,9) -> False
  | (_,_) -> True
  ]
 (* a samboXyaH can be only of the root verb  or an embeded verb in iwi clause 
      else if top=47  && not (bottom=13)  then False *)
;

value relation_mutual_ayogyataa text_type m1 m2=match m1 with
    [ Relationc (to_id1,to_mid1,r1,from_id1,from_mid1) -> match m2 with
      [Relationc (to_id2,to_mid2,r2,from_id2,from_mid2) -> 

(* If there is any kAraka relation, or prayojana or hewu, there can not be viSeRaNa, in case of kqxanwas. 
 * --> prayojana/hewu is possible
 * --> rAmaH piwuH AjFayA vExyaH BUwvA sevAm karowi *)
         (* Allow viRayAXikaraNam;
           xAsyoH vacaneRu mahiRyAH nirAwiSayA SraxXA Bavawi *)
(* need example *)
       if (from_id1=from_id2) && (from_mid1=from_mid2)
              && (  ((r2 > 9 && r2 < 22) && ((r1=32) || (r1=8) || (r1=9)))
                 || ((r1 > 9 && r1 < 22) && ((r2=32) || (r2=8) || (r1=9))))
         then False (* do { print_string "C13"; False} *)
           (* For every prawiyogi, the other end should be either a sambandha
            or anuyogi  or niwya_sambanXa or niwya_sambanXa1(101,102) *)
         else if (from_id1=to_id2) && (from_mid1=to_mid2)
                 &&  (  ((r1=300) && not (r2=44) && not (r2=28) && not(r2=101) && not(r2=102))
                     || ((r2=44) && not (r1=300) && not (r1=28) && not(r1=101) && not(r2=102)))
         then False  (* do { print_string "C14"; False} *)
         else if (from_id2=to_id1) && (from_mid2=to_mid1)
                 && (  ((r2=300) && not (r1=44) && not (r1=28) && not(r1=101) && not(r2=102))
                    || ((r1=44) && not (r2=300) && not (r2=28) && not(r2=101) && not(r2=102)))
         then False (* do { print_string "C15"; False} *)

      (* There can not be a samboXya of a verb, which is viSeRaNa/pUrvakAla etc. Only 'iwi' relation with such verbs are allowed. 
              samboXya=47; vAkyakarama=13 ; prawiyogi=3*)
(* need example *)
         else if (from_id2=to_id1) && (from_mid2=to_mid1)
                && (r2=47) && (r1=13) && not(r1=3)
         then False
         else if (from_id1=to_id2) && (from_mid1=to_mid2)
                && (r1=47) && not (r2=13) && not(r2=3)
         then False
         else if same_root from_id1 from_id2 from_mid1 from_mid2
         then outgoing_incompatible_rels (r1,r2)
         else if sequence from_id2 from_mid2 to_id1 to_mid1
         then not_allowed_sequence_rels (r1,r2)
         else if sequence from_id1 from_mid1 to_id2 to_mid2
         then not_allowed_sequence_rels (r2,r1)
         else True
      ]
    ]
;


value relation_mutual_yogyataa m1 m2=match m1 with
    [ Relationc (to_id1,to_mid1,r1,from_id1,from_mid1) -> match m2 with
      [Relationc (to_id2,to_mid2,r2,from_id2,from_mid2) -> 

         if from_id1=to_id2 && from_mid1=to_mid2
                && r1=24 && not (r2=300) && not (r2=44) (* pUrvakAla is allowed only if either it is directly connected to the main verb, in case there exists another relation then the other relation is either a pratoyogi / anuyogi *)
         then False
         else True
      ]
    ]
;

(*value relation_mutual_expectancy m1 m2 = match m1 with
    [ Relationc (to_id1,to_mid1,r1,from_id1,from_mid1) -> match m2 with
      [Relationc (to_id2,to_mid2,r2,from_id2,from_mid2) -> 
         if sequence from_id2 from_mid2 to_id1 to_mid1
         then sequence_rels r1 r2
         else if sequence from_id1 from_mid1 to_id2 to_mid2
         then sequence_rels r2 r1
         else True
      ]
    ]
;*)

value chk_compatible text_type rel m1 m2=
         single_morph_per_word m1 m2
      && single_relation_label m1 m2
      && no_crossing text_type rel m1 m2 
      && relation_mutual_ayogyataa text_type m1 m2 
      && relation_mutual_yogyataa m1 m2 
      (*&& relation_mutual_expectancy m1 m2*)
;

value rec add_cost text_type acc rels=fun
  [ [] -> acc
  |  [i :: r] ->  match List.nth rels (i-1) with
       [ Relationc (a1,b1,rel,a2,b2) -> let res=
            if rel=101 then 0
            else if rel=102 then 0
            else if rel=8 then 9 (* viXeya_viSeRaNam *)
            else if rel=51 then 0 (* wIvrawAxarSI *)
            else if rel=1079 then 79 (* upamAna *)
            else if rel=64 then 0 (* samuccaya_xyowakaH *)
            else if rel=65 then 0 (* sup_samuccaya_xyowakaH *)
            else if rel=66 then 0 (* anyawara_xyowakaH *)
            else if rel=67 then 0 (* sup_anyawara_xyowakaH *)
            else if rel=55 then 0 (* Gataka_xyowakaH *)
           (* avaXiH not yet defined in build_graph.ml  else if rel=91 then 0 (*  avaXiH *) *)
             (*else if  rel=35 then 35*) (* RaRTI *)
         (*   else if  rel=42 then 42 (* viSeRaNam *) *)
            (*else if  rel=33 then 0 *) (* aBexa *)
            else if  rel> 80 && rel < 90 then 0 (* upapada-LWG relations *)
            else if  rel=78 then 100 (* lyapkarmAXikaraNam ; select this only if there is no other analysis possible *)
          (*  else if rel=53 then 2 * (a2-a1) (*niwya_sambanXaH *)
            else if rel=52 then 3 * (a2-a1) (*prawiyogI *) *)
            else if rel=1009 then 9 * (a2-a1) (* viXeya_viSeRaNam *)
            else if rel=79 then 1 * (a2-a1) (*upamAna *)
            else if rel=80 then 1 * (a2-a1) (* upamAnaxyowakaH *)
            else if rel=76 then 1 * (a2-a1) (* sahArWa_xyowakaH *)
            else if rel=92 then 1 * (a2-a1) (* sahArWaH *)
            else if rel=77 then 1 * (a2-a1) (* vinArWa_xyowakaH *)
            else if rel=93 then 1 * (a2-a1) (* vinArWaH *)
            else if rel >= 2000 && rel < 2100 then 42 * (a2-a1) (*sanxarBa_binxuH *)
            else if rel >= 2200 && rel < 2300 then 14 * (a2-a1) (* karma *)
            else if rel >= 2400 && rel < 2500 then 95 * (a2-a1)  (*ABimuKyam *)
            else if rel >= 2600 && rel < 2700 then 49 * (a2-a1) (* prawiReXaH *)
            else if rel >= 3200 && rel < 3300 then 93 * (a2-a1) (*vinArWaH *)
            (*else if rel >= 3100 && rel < 3200 then 92 * (a2-a1) (*sahArWaH *)*)
            else if rel >= 4000 && rel < 4100 then 20 * (a2-a1) (* apAxAnam *)
            else if rel >= 4100 && rel < 4200 then 21 * (a2-a1) (* xeSAXi *)
            else if rel >= 4200 && rel < 4300 then 9 * (a2-a1) (* viXeya_viSeRaNam *)
            else if rel >= 4300 && rel < 4400 then 28 * (a2-a1) (* sambanXaH *)
            else if rel >= 4400 && rel < 4500 then 7 * (a2-a1) (* karwA *)
            else if rel >= 4500 && rel < 4600 then 25 * (a2-a1) (* aXikaraNa *)
            else if rel >= 205  then (rel-200) * (a2-a1) (* AvaSyakawA/pariNAma *)
            (*else if  rel=64 ||rel=65 || rel=91
                 ||  rel=66 ||rel=67 
                 (* special case of LWG ;
                  * Do not group them together, but treat the cost as 0;
                  * cost is treated as zero in add_cost function *)
            then 0 *)
            (* else rel * (a2-a1) *)
            else if a1 > a2 
                 then if rel=60 then 0
                      else if text_type="Prose" && rel=35
                      then rel * (a1-a2) * 10 (* if the kaarakas or RaRTI are to the right, give penalty *)
                      else rel * (a1-a2) (* no penalty in case of Sloka *)
                 else rel * (a2-a1)
        in add_cost text_type (acc+res) rels r
       ]
  ]
;

value lwg_and_collapse_all_solns text_type rel solns =
        loop [] rel solns
        where rec loop acc rel=fun
        [ [] -> acc
        | [ (len,cost,l)  :: r ] -> let l1=lwg_and_collapse rel l in
                         let len1 = List.length l1 in 
                         let triplet=(len1, cost, l1) in
                         let new_acc=List.append [triplet] acc in
                         loop new_acc rel r
        ]
;


(* Min cost, and largest length *)
value comparecostlength (l1,c1,_) (l2,c2,_) =
    if l1=l2 then compare c1 c2 else compare l2 l1
;

value print_sint i=do
 { print_int i
 ; print_string ";"
 }
;

value get_wrd_ids rel=match rel with
 [ Relationc (id1,id2,id3,id4,id5) -> [id1;id4]
 ]
;

(* for every relation, prepare a list of compatible and non-compatible relations among the relations seen so far *)
(* populate_compatible_lists: Relationc list -> unit *)

(* algo:
   for each relation R between a and b,
    -- mark a,b as a set of compatible words corresponding to relation R
    -- if R compatible with some other relation S between c and d,
    -- then mark c,d as compatible words corresponding to relation R
    -- if R is compatible with S, then add S in the list of compatible relations for R
*)
value populate_compatible_lists text_type rel total_wrds=
  let length=List.length rel -1 in do 
   { for i=0 to length do
     { let reli=List.nth rel i in do
         { (* print_int i
           ;print_string "=>"
           ;print_relation reli 
          ;*) let l=get_wrd_ids reli in
           compatible_words.(i+1) := List.append l compatible_words.(i+1)
          (* a word is compatible with self *)
         ;for j=i+1 to length do
        { let relj=List.nth rel j in
          do {
           let l=get_wrd_ids relj in
           compatible_words.(j+1) := List.append l compatible_words.(j+1)
          (* a word is compatible with self *)
          ;if (chk_compatible text_type rel reli relj)
          then do {
           (* print_int j
           ;print_string " "
           ;print_relation relj 
           ; *) compatible_relations.(i+1) := List.append [j+1] compatible_relations.(i+1)
             ;let l=get_wrd_ids relj in
             compatible_words.(i+1) := List.append l compatible_words.(i+1)
             ;let l=get_wrd_ids reli in
             compatible_words.(j+1) := List.append l compatible_words.(j+1)
          }
          else ()
          } 
        }
     }
     }
    
   ; for i=0 to length do {
      compatible_relations.(i+1) := List.sort_uniq compare compatible_relations.(i+1)
      ;compatible_all_words.(i+1) := List.length (List.sort_uniq compare compatible_words.(i+1)) = total_wrds

 (* compatible_all_words.(i+1) is a boolean, it is true if the i+1th word is potentially related to all other words in the sentence.
This condition is added to ensure that the necessary condition that all the words are related is satisfied.
Thus, for ungrammatical sentences such as rAmaH granWam svapiwi, the parser halts here. However, for sentences such as rAmaH annam svapiwi, since potentially annam being in neuter gender can be a kartA for svapiwi, the programme continues. *)
 
    (* ; print_string "compatible words for "
     ; print_int (i+1)
     ; print_string "="
     ; List.iter print_sint (List.sort_uniq compare compatible_words.(i+1))
     ; print_newline() 
     ; print_int (List.length (List.sort_uniq compare compatible_words.(i+1)))
     ; print_newline() 
     ; print_int total_wrds
     ; print_newline() 
    ; print_string "compatible relations for "
     ; print_int (i+1)
     ; print_string "="
     ; List.iter print_sint compatible_relations.(i+1)
     ; print_newline() 
    *)
   }
  }
;

(* Needed only for debugging
*)
value rec print_acc=fun
[[] -> ()
|[(a,b)::xs] -> do { List.iter print_sint a; print_string " => "
                   ; List.iter print_sint b; print_string "\n"
                   ; print_acc xs
                   }
                   
]
;

(* value rec delete_small size acc=fun
[[] -> acc
|[(a,b)::xs] -> if (List.length a >= size)
                then delete_small size (List.append acc [(a,b)]) xs
                else delete_small size acc xs
]
; *)

value rec delete_small size acc=List.filter (fun (a,b) -> (List.length a >= size)) acc
;

(* Compatible_relations.(i) is empty if none of the following relations are incompatible with i, or i is the last relation, making the 'empty' ambiguous.
Instead of empty list, we produce the same relation *)

(* True if a is subset of b else False*)
value subset a b=List.for_all (fun i -> List.mem i b) a
;

value join_dags dag1 dag2 init final=
(*if dag1=[] then dag2 else 
   if dag2=[] then dag1
   else *)  List.rev ( List.fold_left
      (fun x (a,b) ->
          List.fold_left
          ( fun y (c,d) ->  if subset c b then 
                              if not (a=c) then
                                let l1=List.append a c 
                                and l2=if b=[] then d
                                        else if d=[] then b
                                        else intersection b d 
                                in if ((List.length l1) > (final-init-2))
                                   then List.append [(l1,l2)] y else y
                              else y
                           else y
         ) x dag2
   ) [] dag1
 )
;

value rec get_initial_dag acc start n=
   if n=start then do {
                     (* print_string "n ="
                     ; print_int n
                     ; print_newline()
                     ; print_string "start ="
                     ; print_int start
                     ; print_string "acc="
                     ; print_acc acc
                     ; print_newline()
                     ;*) let dag=List.rev acc in
                     let dag1=join_dags dag dag 0 0 in
                      if dag1=[] then dag else List.append dag dag1
                 } 
                (* else do { print_int n
                 ; if n=0 || compatible_all_words.(n) then print_string "True" else print_string "False"
                ;[]
                } *)
   else  do { (* print_int n
           ; print_newline()
           ; print_string "start="
           ; print_int start
           ; print_newline()
           ; if n=0 || compatible_all_words.(n) then print_string "True" else print_string "False"
           ; print_newline()
         ; *)  if compatible_all_words.(n)
            then let t=compatible_relations.(n) in
                 let p=if t=[] then [n] else t in
                 let l=List.append acc [([n],p)] in
                   get_initial_dag l start (n-1)
            else get_initial_dag acc start (n-1)
         } 
            
;

(* we mark the nodes as root node (2) , leaf node(1) and intermediate node(3) *)
value rec populate_inout_rels length rel =match rel with
    [ [] -> ()
    | [Relationc(a,b,c,d,e)::xs] ->  do {
          (*print_string "inout_rels ="
          ; print_int a
          ; print_string "="
          ; print_int inout_rels.(a)
          ; print_string " "
          ; print_int d
          ; print_string "="
          ; print_int inout_rels.(d)
          ; print_newline()
          ;*)
          if (inout_rels.(a)=0) then inout_rels.(a) := 1
          else if (inout_rels.(a)=2) then inout_rels.(a) := 3
          else ()
          ;if (inout_rels.(d)=0) then inout_rels.(d) := 2
          else if (inout_rels.(d)=1) then inout_rels.(d) := 3
          else ()
          ; populate_inout_rels length xs
          }
    ]
;

value rec construct_dags init final wrdb dags=
   if ( final - init > 0 ) 
   then 
        let mid=(init + final) /2 in
        let dag1=construct_dags init mid wrdb dags in
        let dag2=construct_dags (mid+1) final wrdb dags in  do {
            (* print_int init; print_string " "
            ;print_int mid; print_string " "
            ;print_int final; print_newline()
            ;print_string "dag1= "
            ;print_acc dag1
            ;print_string "dag2= "
            ;print_acc dag2
            ; print_newline()
            ; print_string "init mid final="
            ; print_int init
            ; print_string " "
            ; print_int mid
            ; print_string " "
            ; print_int final
            ; print_newline()
            ; print_string "inout_rels"
            ; print_int inout_rels.(init+1)
            ; print_string " "
            ; print_int inout_rels.(mid+1)
            ; print_newline() 
            ; *) let dag3=join_dags dag1 dag2 init final in
             (* do { print_string "dag3= "
             ;print_acc dag3 
            ; *) let dag4=if (inout_rels.(init+1)=3 || init=mid || dag1=[])
             then List.append dag2 dag3 else dag3 in
             let dag5=if (inout_rels.(final+1)=3 || final=mid+1 || dag2=[])
             then List.append dag1 dag4 else dag4 in
             let dag7=if ((inout_rels.(mid+1)=3) && not (dag1=[]) && not (dag2=[])&& not(init=mid) && not (final=mid+1))
             then let dag6=List.append dag1 dag5 in 
                       List.append dag2 dag6 else dag5 in do {
            
             (* print_string "dag5= "
            ; print_acc dag5
            ;print_newline()
            ;print_string "dag7= "
            ; print_acc dag7
            ;print_newline()
            ; *) let dag8=if dag7=[] then List.append dag1 dag2 else dag7 in do {
            (* print_string "dag8= "
            ; print_acc dag8
            ;print_newline()
            ; print_string "init mid final="
            ; print_int init
            ; print_string " "
            ; print_int mid
            ; print_string " "
            ; print_int final
            ; print_newline()
            ; print_string "size of dag8="
            ; print_int (List.length dag8)
            ; print_newline()
            ; print_acc dag8
            ; print_newline()
            ;*) let dag9=delete_small (final-init-1) dag8 in (*do {
             print_string "dag9= "
            ; print_string "size of dag9="
            ; print_int (List.length dag9)
            ; print_newline()
            ; print_acc dag9
            ; print_newline() 
            ;*) dag9 
             (*} *)
            }
            }
            }
   else 
        if init=0 
        then do {
        (* print_string "calling get_initial"
         ; print_newline()
         ;print_int (List.nth wrdb init)
         ; print_newline()
         ;print_int (List.nth wrdb (init+1))
         ; print_newline()
         ; *) get_initial_dag [] 0 (List.nth wrdb 1)
        }
        (*else if init =1
        then get_initial_dag [] (List.nth wrdb (init-1)) (List.nth wrdb init) *)
        else if init < List.length wrdb && not (init=1)
        then do {
       (* print_int init
       ; print_newline()
       ; *) get_initial_dag [] (List.nth wrdb (init-1)) (List.nth wrdb init)
       }
        else []
;

(*relsindag is a list of relation numbers in a given dag. 
the mapping function below returns the 5-tuple relation for each rel number in a dag.
So maprel contains the list of 5 tuples in a dag *)

value mycount relid maprel=
    loop 0 maprel
    where rec loop acc=fun
    [ [] ->  acc
    | [Relationc (a,b,c,d,e) :: r]  -> if c=relid
                                       then loop (acc+1) r
                                       else loop acc r
    ]
;

(* The number of ca/vA is one less than the number of sups or wifs
 * or =1 *)
(* value ca_vA_compatibility group_count marker_count =
     if (group_count=0 && marker_count=0)
     || (group_count=1 && (group_count=marker_count))
     || (group_count > 1 && (   (group_count=marker_count -1)
                             || (marker_count=1)))
     then True else False
; *)

value ca_vA_compatibility group_count marker_count =

    group_count=0 || group_count=marker_count-1 || marker_count=1 
; 

value samucciwa_anyawara_constraint relations relsindag =
  let maprel=List.map (fun y -> List.nth relations (y-1) ) relsindag in
      let samu_c=mycount 60 maprel
      and sup_samu_c=mycount 61 maprel
      and samu_xyowaka_c=mycount 64 maprel
      and sup_samu_xyowaka_c=mycount 65 maprel
      and anya_c=mycount 62 maprel
      and sup_anya_c=mycount 63 maprel
      and anya_xyowaka_c=mycount 66 maprel
      and sup_anya_xyowaka_c=mycount 67 maprel in
          ca_vA_compatibility sup_samu_c sup_samu_xyowaka_c
       && ca_vA_compatibility samu_c samu_xyowaka_c
       && ca_vA_compatibility sup_anya_c sup_anya_xyowaka_c
       && ca_vA_compatibility anya_c anya_xyowaka_c
;

value rec seq_expectancy relations relsindag =
    let maprel=List.map (fun y -> List.nth relations (y-1) ) relsindag in
        loop maprel
        where rec loop=fun
            [ [] -> True
            | [ Relationc (a,b,r1,c,d) :: rest] -> 
                 (* do { print_string "r1=";print_int r1; print_string "\n"; *)
                  loop1 maprel
                       where rec loop1=fun
                       [ [] -> match r1 with
                              [ 3 | 4 | 5 | 52 | 53 | 76 | 92 | 77 | 93 | 79 | 80 | 40 | 41 | 68 | 69 | 13 | 97 -> False
                              | _ -> loop rest
                              ]
                       | [Relationc (x,y,r2,z,t)::rest1] -> if not(r1=r2) then
    			       (*do { 
                                   print_string "r2=";print_int r2; print_string " ";
                                   print_int a; print_string " ";
                                   print_int b; print_string " ";
                                   print_int c; print_string " ";
                                   print_int d; print_string " ";
                                   print_int x; print_string " ";
                                   print_int y; print_string " ";
                                   print_int z; print_string " ";
                                   print_int t; print_string "\n" ;*)
                               if (z=a && t=b) then 
                                     if (r1 = 3 || r1 = 4 || r1 = 5) then if r2 = 7 then True else loop1 rest1 (* rAme vanam gacCawi sIwA anusarawi *)
                                     else if r1=53 then if r2=52 then True else loop1 rest1
                                     else if r1=92 then if r2=76 then True else loop1 rest1
                                     else if r1=93 then if r2=77 then True else loop1 rest1  (* aham gqham gacCAmi iwi saH avaxaw *)
                                     else if r1=79 then if r2=80 then True else loop1 rest1
                                     else if r1=40 then if r2=41 then True else loop1 rest1
                                     else if r1=68 then if r2=69 then True else loop1 rest1
                                     else if r1=13 then if r2=97 then True else loop1 rest1
                                     else loop rest 
                               else if (c=x && d=y) then
                                     if (r2 = 3 || r2 = 4 || r2 = 5) then if r1 = 7 then True else loop1 rest1 (* rAme vanam gacCawi sIwA anusarawi *)
                                     else if r2=53 then if r1=52 then True else loop1 rest1
                                     else if r2=92 then if r1=76 then True else loop1 rest1
                                     else if r2=93 then if r1=77 then True else loop1 rest1  (* aham gqham gacCAmi iwi saH avaxaw *)
                                     else if r2=79 then if r1=80 then True else loop1 rest1
                                     else if r2=40 then if r1=41 then True else loop1 rest1
                                     else if r2=68 then if r1=69 then True else loop1 rest1
                                     else if r2=13 then if r1=97 then True else loop1 rest1
                                     else loop rest 
                               else if (c=z && d=t) then
                                     if r2=54 then if r1=55 then True else loop1 rest1
                                     else if r1=54 then if r2=55 then True else loop1 rest1
                                     else if r2=60 then if r1=64 then True else loop1 rest1
                                     else if r1=60 then if r2=64 then True else loop1 rest1
                                     else if r2=61 then if r1=65 then True else loop1 rest1
                                     else if r1=61 then if r2=65 then True else loop1 rest1
                                     else if r2=62 then if r1=66 then True else loop1 rest1
                                     else if r1=62 then if r2=66 then True else loop1 rest1
                                     else if r2=63 then if r1=67 then True else loop1 rest1
                                     else if r1=63 then if r2=67 then True else loop1 rest1
                                     else loop rest 
                                else loop1 rest1 (*} *)
                                else loop1 rest1
                       ] (*}*)
            ]
;

value global_compatible text_type relations relsindag=
let maprel=List.map (fun y -> List.nth relations (y-1) ) relsindag in
   loop maprel
   where rec loop=fun
   [ [] -> True
   | [ Relationc (a,b,101,c,d) :: rest]     (* niwya_sambanXaH *)
   | [ Relationc (a,b,102,c,d) :: rest] ->   (* niwya_sambanXaH1 *)
                  loop1 maprel
                  where rec loop1=fun
                     [ [] -> False (* do { print_string "failed case 13"; False} *)
                     | [Relationc (x,y,r1,z,t)::rest1] -> 
                       (* yaw case  2 incoming arrows *)
                       if    x=a && y=b && not (r1=101) && not (r1=102)
                       then loop2 maprel
                       where rec loop2=fun
                       [ [] -> False
                       | [Relationc (m,n,r2,o,p)::rest2] -> 
                          if    m=c && n=d && not (r2=101) && not (r2=102)
                          then loop rest
                          else loop2 rest2
                       ] 
                       else if  x=c && y=d && not (r1=101) && not (r1=102)
                       then loop2 maprel
                       where rec loop2=fun
                       [ [] -> False
                       | [Relationc (m,n,r2,o,p)::rest2] -> 
                          if    o=a && p=b && not (r2=101) && not (r2=102)
                          then loop rest
                          else loop2 rest2
                       ]
                       else loop1 rest1
                     ]
   | [ Relationc (a,b,r1,c,d) :: rest] ->
         if r1=9 || (r1 >= 4400 && r1 < 4500) then
                               (* viXeya_viSeRaNam, karwA *)
                               (* karwA, karwA_upa *)
         loop1 maprel 
         where rec loop1=fun
                          [ [] -> False   (*do { print_string "failed case 5\n"; False}*)
                          | [Relationc (x,y,r,z,t)::rest1] -> 
                                                  (*do {
                                                  print_int r; print_string "\n";
                                                  print_int r1; print_string "\n";*)
                               if not ((r=r1) && (x=a) && (y=b) && (z=c) && (t=d))
                               then if (x=c && y=d && (r1 / 100=44 && r=6))
                                 || (x=c && y=d && r=6 && r1=9) (* && (a-x) > 0   removed, since viXeya_viSeRaNam can be to the left. For example samraWaH aswi janaH *)
                                 || (x=c && y=d && r=24 && r1=9)  (* viXeya_viSeRaNam and pUrvakAlaH *)
                               then  loop rest
                               else  loop1 rest1
                               else  loop1 rest1
                          ]

(* For every upapaxa relation there should be another non-upapaxa relation *)
          else if ( r1 >= 2000  && r1 < 4000 ) then
          loop1 maprel 
          where rec loop1=fun
                          [ [] -> False
                          | [Relationc (x,y,r,z,t)::rest1] -> 
                            if (r>= 4000) 
                                 && ((z=a && t=b) || (x=c && y=d))
                            then loop rest
                            else loop1 rest1
                          ] 
          else if ( r1 >= 4000 ) then
          loop1 maprel 
          where rec loop1=fun
                  [ [] -> False
                          | [Relationc (x,y,r,z,t)::rest1] -> 
                            if  (r < 4000 && r >= 2000) && ((z=a && t=b) || (x=c && y=d) )
                            then loop rest 
                            else loop1 rest1
                          ] 
         else loop rest
   ]
;

value print_pair (a,b) =
  do {print_int a; print_string " "; print_int b; print_string "\n";}
;

value build_list rels dag =
let maprel=List.map (fun y -> List.nth rels (y-1) ) dag in
    loop [] maprel
    where rec loop acc=fun
    [ [] -> (*do { List.iter print_pair acc;*) acc
    | [ Relationc (a,b,r,c,d) :: rest] -> let acc1=[(a,c) :: acc]
					  in loop acc1 rest
    ]
;

value rec chk_cycles key_list v acc =
    (*do { List.iter print_sint key_list;
        print_string "v=";print_int v; print_string "\n";*)
     let acc1=List.filter (fun (k1,v1) -> if k1=v then True else False) acc in
     if acc1=[] then False else loop acc1
     where rec loop=fun
     [[] -> (*do { print_string "chk cycle = False";*) False (*}*)
     | [(k1,v1)::r] -> let key_list1=[k1 :: key_list] in
                       if List.mem v1 key_list then True
                       else if chk_cycles key_list1 v1 acc then True
		       else loop r
     ]
 (* }*)
;

value no_cycles relations relsindag=(*do 
    { List.iter print_sint relsindag; print_string "\n"; *)
      let acc=build_list relations relsindag in loop acc
      where rec loop=fun
      [ [] -> (*do { print_string "no cylcle "; *) True (*}*)
      |[(k,v)::r] -> let key_list=[k] in 
                         if not (chk_cycles key_list v acc) then loop r else False
      ]
(* } *)
;

value rec print_dag=fun
        [ [] -> ()
        | [(a,b,c)::tl] -> do { print_int a; print_int b; List.iter print_int c;
                          print_string "\n";
                          print_dag tl;}
        ]
;

value rec get_list_length acc rels = fun
  [ [] -> acc
  |  [i :: r] ->  match List.nth rels (i-1) with
       [ Relationc (a1,b1,rel,a2,b2) -> if rel > 100 && rel < 200 then get_list_length acc rels r else get_list_length (acc+1) rels r
       ]
  ]
;


(* Get dag list of size n from the array of lists relations, where each list corresponds to a relation and associated dags with it. *)

value rec get_dag_list text_type rel acc=fun
        [ [] -> acc
        | [hd :: tl ] ->   (* do {
                List.iter print_sint hd; print_string " BEFORE\n"; *)
                    if samucciwa_anyawara_constraint rel hd
                    && global_compatible text_type rel hd
                    && seq_expectancy rel hd
                    && no_cycles rel hd
                      then  (*do {
                             List.iter print_sint hd; print_string " AFTER\n"; *)
                         let cost=add_cost text_type 0 rel hd in
                         let len = get_list_length 0 rel hd in
                         let triplet=(len, cost, hd) in
                         let res1=List.append [triplet] acc in
                         get_dag_list text_type rel res1 tl (*}*)
                    else get_dag_list text_type rel acc tl (* }*)
       ]
;

(* To get the total number of words in the sentence
The input is a quintuple (a,b,c,d,e) with a and d the word numbers, c the relation
So we find the largest among all a's and d's to get the total words.
The word numbers start with 1. So the largest word index gives the total words *)
(* largest : int * Relationc list -> int *)

value rec largest rslt=fun
[ [] -> rslt
| [Relationc(a,b,c,d,e) :: r]  ->
         let intmd =
             if a > rslt
             then if a > d then a else d
             else if d > rslt then d else rslt
             in largest intmd r
]
;

value rec wrd_boundaries acc rel_indx wrd_indx rel =match rel with
[ [] -> List.append acc  [rel_indx]
| [Relationc(a,b,c,d,e)::xs] as t -> (*  do {
        print_string "curr index="
        ;print_int a
        ;print_string " rel index="
        ;print_int rel_indx
        ;print_string " word index="
        ;print_int wrd_indx
        ;print_newline ()
        ;List.iter print_int acc
        ;print_newline ()
        ;*)  if a=wrd_indx then
              (* if not (c=2 )
              then  *) wrd_boundaries acc (rel_indx+1) wrd_indx xs
              (* else  wrd_boundaries (List.append acc [rel_indx]) (rel_indx+1) (wrd_indx) xs  *)
             else wrd_boundaries (List.append acc [rel_indx]) (rel_indx) (wrd_indx+1) t
         (*} *)
]
;

(* rel_lst: 5 tuple (to_id,to_mid,rel,from_id.from_mid)
 * text_type: Prose / Sloka *)

value solver rel_lst text_type =
  let total_wrds=(largest 0 rel_lst) in do
  { populate_compatible_lists text_type rel_lst total_wrds
    (*; print_string "initialise inout_rels="
    ; print_int inout_rels.(1)
    ; print_newline() *)
    ;populate_inout_rels (List.length rel_lst -1) rel_lst
    ; let wrdb=wrd_boundaries [0] 0 1 rel_lst in (* do {*)
    (* List.iter print_int wrdb; *)
    let final=
         if List.length wrdb > total_wrds 
         then List.length wrdb-1 
         else (total_wrds-1) in (* do {*)
         (*print_string "final="
       ; print_int final
    ; *) let dags=construct_dags 0 final wrdb [] in (* do {
     print_string "DAGS=" 
     ;print_acc dags 
     ; *)let dagsj=List.fold_left ( fun y (a,b) -> 
           (* if (List.length a=total_wrds-1) *)
            if (List.length a >= total_wrds-3) 
            then [a::y]
            else y) [] dags in 
            let soln=List.sort comparecostlength (get_dag_list text_type rel_lst [] dagsj) in
             let l=List.filter 
              (fun (x,y,z) -> if x >= total_wrds-1 then True else False ) (* To account for niwya sambanXa = is changed to >= *)
              soln in
              if (List.length l > 0)
              then do
              { (* print_string "Total dags="
              ; print_int total_dags_so_far.val
              ; print_newline () ; 
              ;   print_int total_wrds
              ; print_int (List.length l) 
              ; *) let collapsed_soln=lwg_and_collapse_all_solns text_type rel_lst l in
                let uniq_collapsed_soln=List.sort comparecostlength collapsed_soln in do {
                print_string "Total Complete Solutions="
              ; print_int (List.length uniq_collapsed_soln)
              ; print_newline ()
              (*; print_int (List.length soln)
              ; print_newline () *)
              ; print_cost_soln_list 1 (total_wrds-2) rel_lst uniq_collapsed_soln
                }
              (*; print_cost_soln_list 1 (total_wrds-2) rel_lst soln*)
              }
              else do { 
              let l=List.filter 
              (fun (x,y,z) -> if x > total_wrds-3 then True else False ) 
              soln in
              if (List.length l > 0)
              then
                let collapsed_soln=lwg_and_collapse_all_solns text_type rel_lst l in
                let uniq_collapsed_soln=List.sort comparecostlength collapsed_soln in do {
              print_string "Total Partial Solutions="
              ; print_int (List.length uniq_collapsed_soln)
              (*;let psols=(List.length soln - List.length l)
               in print_int psols *)
              ; print_newline ()
              ; print_cost_soln_list 1 (total_wrds-3) rel_lst uniq_collapsed_soln
              (*; print_cost_soln_list 1 0 rel_lst soln
               * TO MODIFY according to new parameter types *)
              } else ()
     } (*}*)
 (*}*)
 (*}*)
 }
;

(*main()
;*)
