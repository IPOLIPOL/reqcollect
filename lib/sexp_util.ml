open Sexplib0.Sexp

let fail fmt = Printf.ksprintf failwith fmt

let atom = function Atom s -> s | _ -> fail "expected atom"
let list = function List xs -> xs | _ -> fail "expected list"

let str = atom

let int = function
  | Atom s -> (try int_of_string s with _ -> fail "expected int, got %s" s)
  | _ -> fail "expected int"

let bool = function
  | Atom "true"  -> true
  | Atom "false" -> false
  | _ -> fail "expected bool"

(* body is the TAIL of a list sexp: [(k1 v1); (k2 v2); ...] *)
let find key body =
  let rec go = function
    | [] -> fail "missing field: %s" key
    | List [Atom k; v] :: _ when String.equal k key -> v
    | _ :: rest -> go rest
  in
  go body

let find_opt key body =
  try Some (find key body) with Failure _ -> None

let find_all key body =
  List.filter
    (function
      | List (Atom k :: _) -> String.equal k key
      | _ -> false)
    body

(* Returns the list of everything after the key in (key v1 v2 ... vn). *)
let find_multi key body =
  let rec go = function
    | [] -> None
    | List (Atom k :: vs) :: _ when String.equal k key -> Some vs
    | _ :: rest -> go rest
  in
  go body

let find_multi_exn key body =
  match find_multi key body with
  | Some vs -> vs
  | None -> fail "missing field: %s" key