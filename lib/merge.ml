open Sexplib0.Sexp
module Sexp = Sexplib0.Sexp

type merged = {
  id         : string;
  display_id : string;
  group      : string;
  text       : string;
  source     : string option;
  note       : string option;
  headers    : (string * string) list;   (* was: author : string *)
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
              headers = s.Submission.headers })
         s.Submission.requirements)
    subs

let to_sexp ~batch_id ~schema_id ~schema_version (ms : merged list) : Sexp.t =
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
      @ [ List [Atom "headers"; List (List.map (fun (k, v) -> List [Atom k; Atom v]) m.headers)] ])
  in
  List (
    [ Atom "merged";
      List [Atom "batch-id";       Atom batch_id];
      List [Atom "schema-id";      Atom schema_id];
      List [Atom "schema-version"; Atom schema_version];
      List [Atom "count";          Atom (string_of_int (List.length ms))];
      List (Atom "requirements" :: List.map req_sexp ms) ])


(* read-back a merged.sexp so `render` can consume it *)

let parse_requirement = function
  | List (Atom "requirement" :: body) ->
    let opt k = match Sexp_util.find_opt k body with
      | Some (Atom s) -> Some s
      | _ -> None in
    let headers =
      match Sexp_util.find_opt "headers" body with
      | Some (List (List _ :: _ as hs)) ->
        List.filter_map (function
          | List [Atom k; Atom v] -> Some (k, v)
          | _ -> None) hs
      | _ -> []
    in
    { id         = Option.value ~default:"" (opt "id");
      display_id = Option.value ~default:"" (opt "display-id");
      group      = Option.value ~default:"" (opt "group");
      text       = Option.value ~default:"" (opt "text");
      source     = opt "source";
      note       = opt "note";
      headers    }
  | _ -> failwith "expected (requirement ...)"

let load path =
  match Sexplib.Sexp.load_sexp path with
  | List (Atom "merged" :: body) ->
    (match Sexp_util.find_multi "requirements" body with
     | None    -> []
     | Some vs -> List.map parse_requirement vs)
  | _ -> failwith "expected (merged ...)"