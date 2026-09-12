open Sexplib0.Sexp
open Sexp_util

type requirement = {
  group : string;
  text : string;
  source : string option;
  note : string option;
}

type t = {
  schema_id : string;
  schema_version : string;
  created_at : string;
  author : string;
  requirements : requirement list;
}

let parse_requirement = function
  | List (Atom "requirement" :: body) ->
    { group = str (find "group" body);
      text = str (find "text" body);
      source = Option.map str (find_opt "source" body);
      note = Option.map str (find_opt "note" body) }
  | _ -> failwith "expected (requirement ...)"

let of_sexp = function
  | List (Atom "submission" :: body) ->
    let reqs =
      match find_multi "requirements" body with
      | None -> []
      | Some vs -> List.map parse_requirement vs
    in
    { schema_id = str (find "schema-id" body);
      schema_version = str (find "schema-version" body);
      created_at = str (find "created-at" body);
      author = str (find "author" body);
      requirements = reqs }
  | _ -> failwith "expected (submission ...)"

let load path = Sexplib.Sexp.load_sexp path |> of_sexp