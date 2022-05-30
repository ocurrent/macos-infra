open Cmdliner

let reporter =
  let report src level ~over k msgf =
    let k _ =
      over ();
      k ()
    in
    let src = Logs.Src.name src in
    msgf @@ fun ?header ?tags:_ fmt ->
    Fmt.kpf k Fmt.stdout
      ("%a %a @[" ^^ fmt ^^ "@]@.")
      Fmt.(styled `Magenta string)
      (Printf.sprintf "%14s" src)
      Logs_fmt.pp_header (level, header)
  in
  { Logs.report }

let init style_renderer level =
  Fmt_tty.setup_std_outputs ?style_renderer ();
  Logs.set_level level;
  Logs.set_reporter reporter

let setup_log =
  Term.(const init $ Fmt_cli.style_renderer () $ Logs_cli.level ())

let ov_term =
  let ov =
    ( (fun s ->
        try `Ok (Ocaml_version.of_string_exn s)
        with Invalid_argument s -> `Error s),
      Ocaml_version.pp )
  in
  Arg.required
  @@ Arg.opt Arg.(some ov) None
  @@ Arg.info ~doc:"The OCaml version to build." ~docv:"OCAML"
       [ "ocaml-version" ]

let rsync_term =
  Arg.required
  @@ Arg.opt Arg.(some string) None
  @@ Arg.info ~doc:"The rsync directory to store results." ~docv:"RSYNC"
       [ "rsync" ]

let docker_repo_term =
  Arg.value
  @@ Arg.opt Arg.(some string) None
  @@ Arg.info ~doc:"The docker repository, e.g. ocaml/opam." ~docv:"REPO"
       [ "docker-repo" ]

let duration_term =
  let schedule =
    let parser s =
      match int_of_string_opt s with
      | None -> Error (`Msg ("Couldn't parse the number of days: " ^ s))
      | Some d -> Ok (Duration.of_day d)
    in
    Cmdliner.Arg.conv (parser, Duration.pp)
  in
  Arg.value
  @@ Arg.opt Arg.(some schedule) None
  @@ Arg.info ~doc:"How often to retrigger the pipeline to rebuild the images."
       ~docv:"SCHEDULE" [ "schedule" ]

let dockerfile username =
  let open Dockerfile in
  from "scratch"
  @@ copy ~src:[ "./" ^ username ] ~dst:"/" ()
  @@ cmd_exec [ "/bin/bash" ]
  |> string_of_t

let pipeline ~docker_repo ~ocaml_version ~rsync_path ~sandbox_config schedule =
  let open Macos_base_image in
  let user =
    Current_obuilder.build ~ocaml_version ~rsync_path ~sandbox_config schedule
  in
  match docker_repo with
  | None -> user
  | Some docker_repo ->
      let path = Current.map (fun user -> Fpath.(v "/Users" / user)) user in
      let dockerfile =
        Current.map (fun user -> `Contents (dockerfile user)) user
      in
      let image =
        Current_docker.Default.build ~dockerfile ~pull:true (`Dir path)
      in
      Current_docker.Default.push
        ~tag:(docker_repo ^ ":" ^ make_tag ocaml_version)
        image

let cmd =
  let doc = "Builder for macOS base images" in
  let main () config valid_for mode docker_repo ocaml_version rsync_path
      sandbox_config =
    let schedule = Current_cache.Schedule.v ?valid_for () in
    let engine =
      Current.Engine.create ~config (fun () ->
          Current.ignore_value
          @@ pipeline ~docker_repo ~ocaml_version ~rsync_path ~sandbox_config
               schedule)
    in
    let site =
      Current_web.Site.(v ~has_role:allow_all)
        ~name:"macos-base-images"
        (Current_web.routes engine)
    in
    match
      Lwt_main.run
        (Lwt.choose
           [ Current.Engine.thread engine; Current_web.run ~mode site ])
    with
    | Ok s -> print_endline s
    | Error (`Msg m) -> failwith m
  in
  Cmd.v
    (Cmd.info "macos-base-image" ~doc)
    Term.(
      const main $ setup_log $ Current.Config.cmdliner $ duration_term
      $ Current_web.cmdliner $ docker_repo_term $ ov_term $ rsync_term
      $ Obuilder.Sandbox.cmdliner)

let () = Cmd.(exit @@ eval cmd)
