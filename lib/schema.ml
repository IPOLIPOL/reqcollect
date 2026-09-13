open Sexplib0.Sexp
open Sexp_util

type group = { id : string; name : string; order : int }
type field = { id : string; name : string; data_type : string; required : bool }

type header_field = {
  id          : string;
  name        : string;
  placeholder : string;
  required    : bool;
}

type t = {
  id            : string;
  name          : string;
  version       : string;
  header_fields : header_field list;
  groups        : group list;
  fields        : field list;
}

let parse_group = function
  | List (Atom "group" :: body) ->
    { id = str (find "id" body);
      name = str (find "name" body);
      order = int (find "order" body) }
  | _ -> failwith "expected (group ...)"

let parse_field = function
  | List (Atom "field" :: body) ->
    { id = str (find "id" body);
      name = str (find "name" body);
      data_type = str (find "data-type" body);
      required = bool (find "required" body) }
  | _ -> failwith "expected (field ...)"

let parse_header_field = function
  | List (Atom "header-field" :: body) ->
    { id          = str (find "id" body);
      name        = str (find "name" body);
      placeholder = (match find_opt "placeholder" body with
                     | Some v -> str v
                     | None   -> "");
      required    = bool (find "required" body) }
  | _ -> failwith "expected (header-field ...)"

let of_sexp = function
  | List (Atom "schema" :: body) ->
    { id = str (find "id" body);
      name = str (find "name" body);
      version = str (find "version" body);
      header_fields = List.map parse_header_field (find_all "header-field" body);
      groups = List.map parse_group (find_all "group" body);
      fields = List.map parse_field (find_all "field" body) }
  | _ -> failwith "expected (schema ...)"

let load path = Sexplib.Sexp.load_sexp path |> of_sexp