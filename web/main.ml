open Js_of_ocaml

let doc = Dom_html.document
let jstr = Js.string
let to_ocaml = Js.to_string

(* --- tiny DOM helpers --- *)

let text_node s = doc##createTextNode (jstr s)
let append p c = ignore (Dom.appendChild p c)

let div ?(cls = "") () =
  let d = Dom_html.createDiv doc in
  if cls <> "" then d##.className := jstr cls;
  d

let input ?(typ = "text") ?(cls = "") ?(ph = "") () =
  let i = Dom_html.createInput ~_type:(jstr typ) doc in
  if cls <> "" then i##.className := jstr cls;
  if ph  <> "" then i##.placeholder := jstr ph;
  i

let button label =
  let b = Dom_html.createButton doc in
  append b (text_node label);
  b

let heading level s =
  let tag = Printf.sprintf "h%d" level in
  let e = doc##createElement (jstr tag) in
  append e (text_node s);
  e

let span cls s =
  let e = doc##createElement (jstr "span") in
  e##.className := jstr cls;
  append e (text_node s);
  e

let on_click el f =
  ignore (Dom_html.addEventListener el Dom_html.Event.click
    (Dom_html.handler (fun _ -> f (); Js._false)) Js._false)

let value (i : Dom_html.inputElement Js.t) = to_ocaml i##.value

(* --- schema --- *)
let schema =
  Schema.of_sexp (Sexplib.Sexp.of_string Schema_data.text)

(* --- header inputs (filled once at the top of the form) --- *)
let header_inputs :
  (Schema.header_field * Dom_html.inputElement Js.t) list ref = ref []

(* --- requirement rows --- *)
type row = {
  text_in   : Dom_html.inputElement Js.t;
  source_in : Dom_html.inputElement Js.t;
  note_in   : Dom_html.inputElement Js.t;
  el        : Dom_html.divElement Js.t;
}

let rows_by_group : (string, row list ref) Hashtbl.t = Hashtbl.create 16

let rows_of group =
  match Hashtbl.find_opt rows_by_group group with
  | Some rs -> rs
  | None ->
    let rs = ref [] in
    Hashtbl.add rows_by_group group rs;
    rs

let make_row group container =
  let r = {
    text_in   = input ~cls:"text"   ~ph:"Requirement" ();
    source_in = input ~cls:"source" ~ph:"Source" ();
    note_in   = input ~cls:"note"   ~ph:"Note" ();
    el        = div ~cls:"row" ();
  } in
  append r.el r.text_in;
  append r.el r.source_in;
  append r.el r.note_in;
  let del = button "×" in
  append r.el del;
  append container r.el;
  let rs = rows_of group in
  rs := r :: !rs;
  on_click del (fun () ->
    ignore (Dom.removeChild container r.el);
    rs := List.filter (fun x -> x != r) !rs);
  r

(* --- sexp serialization --- *)

let quote s =
  let b = Buffer.create (String.length s + 2) in
  Buffer.add_char b '"';
  String.iter (function
    | '"'  -> Buffer.add_string b "\\\""
    | '\\' -> Buffer.add_string b "\\\\"
    | '\n' -> Buffer.add_string b "\\n"
    | '\t' -> Buffer.add_string b "\\t"
    | c    -> Buffer.add_char b c) s;
  Buffer.add_char b '"';
  Buffer.contents b

let iso_now () =
  Js.to_string (Js.Unsafe.eval_string "new Date().toISOString()")

let build_submission () =
  let b = Buffer.create 1024 in
  Buffer.add_string b "(submission\n";
  Buffer.add_string b " (schema-id crane)\n";
  Buffer.add_string b " (schema-version 0.1.0)\n";
  Buffer.add_string b (Printf.sprintf " (created-at %s)\n" (quote (iso_now ())));
  Buffer.add_string b " (headers\n";
  List.iter (fun ((h : Schema.header_field), i) ->
    let v = String.trim (value i) in
    if v <> "" then
      Buffer.add_string b (Printf.sprintf "  (%s %s)\n" h.id (quote v)))
    (List.rev !header_inputs);
  Buffer.add_string b "  )\n";
  Buffer.add_string b " (requirements\n";
  Hashtbl.iter (fun group rs ->
    List.iter (fun r ->
      let text   = String.trim (value r.text_in)   in
      let source = String.trim (value r.source_in) in
      let note   = String.trim (value r.note_in)   in
      if text <> "" then begin
        Buffer.add_string b "  (requirement\n";
        Buffer.add_string b (Printf.sprintf "   (group %s)\n" group);
        Buffer.add_string b (Printf.sprintf "   (text %s)\n"   (quote text));
        if source <> "" then
          Buffer.add_string b (Printf.sprintf "   (source %s)\n" (quote source));
        if note <> "" then
          Buffer.add_string b (Printf.sprintf "   (note %s)\n"   (quote note));
        Buffer.add_string b "   )\n"
      end) !rs)
    rows_by_group;
  Buffer.add_string b "  ))\n";
  Buffer.contents b

(* --- download --- *)

let download ~filename content =
  let uri =
    "data:text/plain;charset=utf-8,"
    ^ (Js.to_string (Js.encodeURIComponent (jstr content)))
  in
  let a = doc##createElement (jstr "a") in
  a##setAttribute (jstr "href")     (jstr uri);
  a##setAttribute (jstr "download") (jstr filename);
  append doc##.body a;
  ignore (Js.Unsafe.meth_call a "click" [||]);
  ignore (Dom.removeChild doc##.body a)

(* --- build the app --- *)

let () =
  let app = match Dom_html.getElementById_opt "app" with
    | Some e -> e
    | None -> Dom_html.document##.body
  in

  append app (heading 1 "Requirements sheet");

List.iter (fun (h : Schema.header_field) ->
  let row = div ~cls:"header-row" () in
  append row (span "field-label" (h.Schema.name ^ ":"));
  let i = input ~cls:"header-in" ~ph:h.Schema.placeholder () in
  append row i;
  append app row;
  header_inputs := (h, i) :: !header_inputs)
  schema.Schema.header_fields;

  (* groups *)
  List.iter (fun (g : Schema.group) ->
    let sec = div ~cls:"group" () in
    sec##setAttribute (jstr "data-group") (jstr g.Schema.id);
    append sec (heading 2 g.Schema.name);

    let rows_container = div ~cls:"rows" () in
    append sec rows_container;

    let add = button "+ Add requirement" in
    append sec add;
    on_click add (fun () -> ignore (make_row g.Schema.id rows_container));

    append app sec;
    ignore (make_row g.Schema.id rows_container))
    schema.Schema.groups;

  (* export *)
  let exp = button "Export .sexp" in
  append app exp;
  on_click exp (fun () ->
    download ~filename:"submission.sexp" (build_submission ()))