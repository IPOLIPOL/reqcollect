open Cmdliner

let ensure_dir path =
  if not (Sys.file_exists path) then Unix.mkdir path 0o755

let run paths out_path batch_id =
  match paths with
  | [] -> failwith "need: SCHEMA.sexp SUBMISSION.sexp [SUBMISSION.sexp ...]"
  | schema_path :: sub_paths ->
    if sub_paths = [] then
      failwith "need at least one submission file";
    let schema = Schema.load schema_path in
    let subs = List.map Submission.load sub_paths in
    let merged = Merge.merge ~batch_id subs in
    let sexp =
      Merge.to_sexp
        ~batch_id
        ~schema_id:schema.Schema.id
        ~schema_version:schema.Schema.version
        merged
    in
    ensure_dir (Filename.dirname out_path);
    Out_channel.with_open_bin out_path (fun oc ->
      Out_channel.output_string oc (Sexplib.Sexp.to_string_hum ~indent:1 sexp);
      Out_channel.output_string oc "\n");
    Printf.printf "Merged %d requirement(s) into %s\n"
      (List.length merged) out_path

let merge_cmd =
  let paths =
    Arg.(non_empty & pos_all file [] &
         info [] ~docv:"SCHEMA.sexp SUBMISSION.sexp...")
  in
  let out =
    Arg.(value & opt string "repo/merged.sexp" & info ["o"; "out"] ~docv:"PATH")
  in
  let batch =
    Arg.(value & opt string "batch-001" & info ["b"; "batch"] ~docv:"ID")
  in
  Cmd.v
    (Cmd.info "merge" ~doc:"Merge submissions into a central sexp file")
    Term.(const run $ paths $ out $ batch)


let read_file path =
  let ic = open_in_bin path in
  let n = in_channel_length ic in
  let s = really_input_string ic n in
  close_in ic; s

let run_render merged_path schema_path template_path out_path =
  let schema   = Schema.load schema_path in
  let ms       = Merge.load merged_path in
  let template = read_file template_path in
  let html     = Render_html.render ~schema ~template ms in
  ensure_dir (Filename.dirname out_path);
  Out_channel.with_open_bin out_path (fun oc ->
    Out_channel.output_string oc html);
  Printf.printf "Rendered %d requirement(s) into %s\n"
    (List.length ms) out_path

let render_cmd =
  let merged_path =
    Arg.(required & pos 0 (some file) None & info [] ~docv:"MERGED.sexp") in
  let schema_path =
    Arg.(required & opt (some file) None
           & info ["s"; "schema"] ~docv:"SCHEMA.sexp") in
  let template_path =
    Arg.(value & opt file "web/merged_template.html"
           & info ["t"; "template"] ~docv:"TEMPLATE.html") in
  let out_path =
    Arg.(value & opt string "repo/merged.html"
           & info ["o"; "out"] ~docv:"PATH") in
  Cmd.v
    (Cmd.info "render" ~doc:"Render merged.sexp to a single HTML file")
    Term.(const run_render $ merged_path $ schema_path $ template_path $ out_path)



let () =
  let info = Cmd.info "reqcollect" ~version:"0.1.0" in
  exit (Cmd.eval (Cmd.group info [merge_cmd; render_cmd]))

