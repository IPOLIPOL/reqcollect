open Sexplib0.Sexp
module Sexp = Sexplib0.Sexp

type merged = {
  id : string;
  display_id : string;
  group : string;
  text : string;
  source : string option;
  note : string option;
  author : string;
}

let abbrev = function
  | "purpose"       -> "PURP"
  | "functional"    -> "FUNC"
  | "performance"   -> "PERF"
  | "regulatory"    -> "REG"
  | "environmental" -> "ENV"
  | "interface"     -> "IFC"
  | "safety"        -> "SAF"
  | "testing"       -> "TEST"
  | "manufacturing" -> "MFG"
  | g -> String.uppercase_ascii g

let merge ~batch_id (subs : Submission.t list) : merged list =
  let counters = Hashtbl.create 16 in
  let ordinal = ref 0 in
  List.concat_map
    (fun (s : Submission.t) ->
       List.map
         (fun (r : Submission.requirement) ->
            incr ordinal;
            let n =
              let prev = try Hashtbl.find counters r.group with Not_found -> 0 in
              Hashtbl.replace counters r.group (prev + 1);
              prev + 1
            in
            { id = Printf.sprintf "%s-%04d" batch_id !ordinal;
              display_id = Printf.sprintf "REQ-%s-%04d" (abbrev r.group) n;
              group = r.group;
              text = r.text;
              source = r.source;
              note = r.note;
              author = s.author })
         s.Submission.requirements)
    subs

let to_sexp ~batch_id (ms : merged list) : Sexp.t =
  let req_sexp (m : merged) =
    List (
      [ Atom "requirement";
        List [Atom "id"; Atom m.id];
        List [Atom "display-id"; Atom m.display_id];
        List [Atom "group"; Atom m.group];
        List [Atom "text"; Atom m.text] ]
      @ (match m.source with
         | Some s -> [List [Atom "source"; Atom s]]
         | None -> [])
      @ (match m.note with
         | Some n -> [List [Atom "note"; Atom n]]
         | None -> [])
      @ [ List [Atom "author"; Atom m.author] ])
  in
  List (
    [ Atom "merged";
      List [Atom "batch-id"; Atom batch_id];
      List [Atom "count"; Atom (string_of_int (List.length ms))];
      List (Atom "requirements" :: List.map req_sexp ms) ])