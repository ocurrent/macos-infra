(* Build a macOS base image *)
open Lwt.Syntax
module Fetcher = Obuilder.Docker
module Sandbox = Obuilder.Sandbox

module Log = struct
  let src = Logs.Src.create "macos-builder" ~doc:"building macos base images"

  include (val Logs.src_log src : Logs.LOG)
end

let ( / ) = Filename.concat

let spec_file ocaml_version =
  let open Obuilder_spec in
  stage ~from:"patricoferris/empty"
    [
      env "tmpdir" "$(getconf DARWIN_USER_TEMP_DIR)";
      run
        "\"$(curl -fsSL \
         https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"";
      run "git clone -b 2.0 git://github.com/ocaml/opam ./opam";
      run
        "cd ./opam && make cold && mkdir -p ~/local/bin && cp ./opam \
         ~/local/bin/opam-2.0 && chmod a+x ~/local/bin/opam-2.0 && cd ../ && \
         rm -rf ./opam";
      run "git clone -b 2.1 git://github.com/ocaml/opam ./opam";
      run
        "cd ./opam && make CONFIGURE_ARGS=--with-0install-solver cold && mkdir \
         -p ~/local/bin && cp ./opam ~/local/bin/opam-2.1 && chmod a+x \
         ~/local/bin/opam-2.1 && cd ../ && rm -rf ./opam";
      run "ln ~/local/bin/opam-2.0 ~/local/bin/opam";
      run
        "echo 'export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin' >> \
         ./.obuilder_profile.sh";
      run
        "echo 'export PATH=/opt/homebrew/bin:/opt/homebrew/sbin:$PATH' >> \
         ./.obuilder_profile.sh";
      run
        "echo 'export PATH=/Users/administrator/ocaml/%s/bin:$PATH' >> \
         ./.obuilder_profile.sh"
        (Ocaml_version.to_string ocaml_version);
      run "source ./.obuilder_profile.sh";
      run "git clone git://github.com/ocaml/opam-repository.git";
      run "opam init -k git -a ./opam-repository";
      run "opam install -y opam-depext";
      run "echo 'export OPAMYES=1' >> ./.obuilder_profile.sh";
      run "echo 'export OPAMCONFIRMLEVEL=unsafe-yes' >> ./.obuilder_profile.sh";
      run "echo 'export OPAMERRLOGLEN=0' >> ./.obuilder_profile.sh";
      run "echo 'export OPAMPRECISETRACKING=1' >> ./.obuilder_profile.sh";
    ]

let main ocaml_version rsync_path sandbox_config =
  let* (Store ((module Store), store)) =
    Obuilder.Store_spec.to_store (`Rsync rsync_path)
  in
  let module Builder = Obuilder.Builder (Store) (Sandbox) (Fetcher) in
  let* sandbox =
    Sandbox.create ~state_dir:(Store.state_dir store / "runc") sandbox_config
  in
  let builder = Builder.v ~store ~sandbox in
  let log tag str =
    match tag with
    | `Heading -> Log.info (fun f -> f "%s" str)
    | `Note -> Log.info (fun f -> f "%s" str)
    | `Output -> Log.info (fun f -> f "%s" str)
  in
  let context = Obuilder.Context.v ~log ~src_dir:"." () in
  Log.info (fun f ->
      f "Building base image for %a" Ocaml_version.pp ocaml_version);
  Builder.build builder context (spec_file ocaml_version)

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
  @@ Arg.info ~doc:"The OCaml version to build." ~docv:"OCAML" [ "ocaml-version" ]

let rsync_term =
  Arg.required
  @@ Arg.opt Arg.(some dir) None
  @@ Arg.info ~doc:"The rsync directory to store results." ~docv:"RSYNC"
       [ "rsync" ]

let cmd =
  let doc = "Builder for macOS base images" in
  let main () ov rsync sandbox =
    match Lwt_main.run (main ov rsync sandbox) with
    | Ok s -> print_endline s
    | Error (`Msg m) -> failwith m
    | Error `Cancelled -> ()
  in
  ( Term.(
      const main $ setup_log $ ov_term $ rsync_term $ Obuilder.Sandbox.cmdliner),
    Term.info "macos-base-image" ~doc )

let () = Term.(exit @@ eval cmd)
