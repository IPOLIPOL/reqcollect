(* Renders a list of merged requirements into a single self-contained
   HTML file, using the template's <!-- NAV --> / <!-- CONTENT -->
   placeholders. Pure: input data + template string, output string. *)

let esc s =
  let b = Buffer.create (String.length s) in
  String.iter (function
    | '&'  -> Buffer.add_string b "&amp;"
    | '<'  -> Buffer.add_string b "&lt;"
    | '>'  -> Buffer.add_string b "&gt;"
    | '"'  -> Buffer.add_string b "&quot;"
    | c    -> Buffer.add_char b c) s;
  Buffer.contents b

let header_get headers key =
  match List.assoc_opt key headers with
  | Some v when v <> "" -> Some v
  | _ -> None

(* --- grouping --- *)

let group_by_system (ms : Merge.merged list) =
  let order = ref [] in
  let tbl = Hashtbl.create 16 in
  List.iter (fun (m : Merge.merged) ->
    let sys = match header_get m.headers "system-name" with
      | Some s -> s
      | None   -> "(no system)" in
    (match Hashtbl.find_opt tbl sys with
     | None   -> order := sys :: !order; Hashtbl.add tbl sys [m]
     | Some _ -> Hashtbl.replace tbl sys (m :: Hashtbl.find tbl sys)))
    ms;
  List.rev_map (fun sys -> (sys, List.rev (Hashtbl.find tbl sys))) !order

let group_by_group (ms : Merge.merged list) =
  let order = ref [] in
  let tbl = Hashtbl.create 16 in
  List.iter (fun (m : Merge.merged) ->
    (match Hashtbl.find_opt tbl m.group with
     | None   -> order := m.group :: !order; Hashtbl.add tbl m.group [m]
     | Some _ -> Hashtbl.replace tbl m.group (m :: Hashtbl.find tbl m.group)))
    ms;
  List.rev_map (fun g -> (g, List.rev (Hashtbl.find tbl g))) !order

let group_label (schema : Schema.t) gid =
  match List.find_opt
          (fun (g : Schema.group) -> g.Schema.id = gid)
          schema.Schema.groups with
  | Some g -> g.Schema.name
  | None   -> gid

(* --- render helpers --- *)

let meta (m : Merge.merged) =
  let rows = ref [] in
  let push k v = rows := Printf.sprintf "<dt>%s</dt><dd>%s</dd>" (esc k) (esc v) :: !rows in
  (match m.source with Some s when s <> "" -> push "Source" s | _ -> ());
  (match m.note   with Some n when n <> "" -> push "Note" n   | _ -> ());
  List.iter (fun (k, v) ->
    if v <> "" && k <> "system-name" && k <> "author" then push k v)
    m.headers;
  (match header_get m.headers "author" with
   | Some a -> push "Author" a
   | None   -> ());
  match List.rev !rows with
  | [] -> ""
  | rs -> Printf.sprintf "<dl class=\"meta\">%s</dl>" (String.concat "" rs)

let req (m : Merge.merged) =
  Printf.sprintf
    "<article class=\"req\">\n<header><span class=\"req-id\">%s</span></header>\n<p class=\"req-text\">%s</p>\n%s\n</article>"
    (esc m.display_id) (esc m.text) (meta m)

let group_section ~schema ~sys_anchor gid reqs =
  let anchor = Printf.sprintf "%s-%s" sys_anchor gid in
  Printf.sprintf
    "<section class=\"group\" id=\"%s\">\n<h3>%s <span class=\"count\">(%d)</span></h3>\n%s\n</section>"
    (esc anchor) (esc (group_label schema gid)) (List.length reqs)
    (String.concat "\n" (List.map req reqs))

let system_section ~schema ~idx (sysname, ms) =
  let anchor = Printf.sprintf "sys-%d" idx in
  let by_group = group_by_group ms in
  Printf.sprintf
    "<section class=\"system\" id=\"%s\">\n<h2>%s</h2>\n%s\n</section>"
    (esc anchor) (esc sysname)
    (String.concat "\n"
       (List.map (fun (gid, rs) -> group_section ~schema ~sys_anchor:anchor gid rs)
          by_group))

let nav_list ~schema systems =
  let one idx (sysname, ms) =
    let anchor = Printf.sprintf "sys-%d" idx in
    let subs =
      String.concat "\n"
        (List.map (fun (gid, rs) ->
           Printf.sprintf
             "      <li><a href=\"#%s-%s\">%s <span class=\"count\">(%d)</span></a></li>"
             anchor gid
             (esc (group_label schema gid))
             (List.length rs))
           (group_by_group ms))
    in
    Printf.sprintf
      "    <li>\n      <details open>\n        <summary><a href=\"#%s\" onclick=\"event.stopPropagation()\">%s <span class=\"count\">(%d)</span></a></summary>\n        <ul>\n%s\n        </ul>\n      </details>\n    </li>"
      anchor (esc sysname) (List.length ms) subs
  in
  String.concat "\n" (List.mapi (fun i s -> one (i + 1) s) systems)

(* --- template substitution --- *)

let replace_all ~needle ~repl hay =
  let n = String.length needle in
  if n = 0 then hay
  else begin
    let b = Buffer.create (String.length hay) in
    let len = String.length hay in
    let rec go i =
      if i > len - n then Buffer.add_substring b hay i (len - i)
      else if String.sub hay i n = needle then
        (Buffer.add_string b repl; go (i + n))
      else
        (Buffer.add_char b hay.[i]; go (i + 1))
    in
    go 0;
    Buffer.contents b
  end

let render ~schema ~template (ms : Merge.merged list) : string =
  let systems = group_by_system ms in
  let nav  = nav_list ~schema systems in
  let body =
    String.concat "\n"
      (List.mapi (fun i s -> system_section ~schema ~idx:(i+1) s) systems)
  in
  template
  |> replace_all ~needle:"<!-- NAV -->"     ~repl:nav
  |> replace_all ~needle:"<!-- CONTENT -->" ~repl:body