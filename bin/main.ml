open Cmdliner

let ensure_dir path =
  if not (Sys.file_exists path) then Unix.mkdir path 0o755

let run paths out_path batch_id =
  match paths with
  | [] -> failwith "need: SCHEMA.sexp SUBMISSION.sexp [SUBMISSION.sexp ...]"
  | schema_path :: sub_paths ->
    if sub_paths = [] then
      failwith "need at least one submission file";
    ignore (Schema.load schema_path);
    let subs = List.map Submission.load sub_paths in
    let merged = Merge.merge ~batch_id subs in
    let sexp = Merge.to_sexp ~batch_id merged in
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

let () =
  let info = Cmd.info "reqcollect" ~version:"0.1.0" in
  exit (Cmd.eval (Cmd.group info [merge_cmd]))