module Fetcher = Obuilder.Docker
module Sandbox = Obuilder.Sandbox

let spec_file ocaml_version =
  let open Obuilder_spec in
  stage ~from:"patricoferris/empty"
    [
      run
        "/bin/bash -c \"$(curl -fsSL \
         https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"";
      run
        "git clone -b backport-4927-2.0 https://github.com/kit-ty-kate/opam \
         ./opam";
      run
        "cd ./opam && make cold && mkdir -p ~/local/bin && cp ./opam \
         ~/local/bin/opam-2.0 && chmod a+x ~/local/bin/opam-2.0 && cd ../ && \
         rm -rf ./opam ";
      run "git clone -b 2.1 https://github.com/ocaml/opam ./opam";
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
      run "git clone https://github.com/ocaml/opam-repository.git";
      run
        "source ~/.obuilder_profile.sh && opam init -k git -a ./opam-repository";
      run "source ~/.obuilder_profile.sh && opam install -y opam-depext";
      run "echo 'export OPAMYES=1' >> ./.obuilder_profile.sh";
      run "echo 'export OPAMCONFIRMLEVEL=unsafe-yes' >> ./.obuilder_profile.sh";
      run "echo 'export OPAMERRLOGLEN=0' >> ./.obuilder_profile.sh";
      run "echo 'export OPAMPRECISETRACKING=1' >> ./.obuilder_profile.sh";
    ]

module Build_op = struct
  open Lwt.Infix

  type t = No_context

  let ( >>!= ) = Lwt_result.bind

  module Key = struct
    type t = {
      ocaml_version : Ocaml_version.t;
      rsync_path : string;
      sandbox_config : Sandbox.config;
    }

    let to_yojson { ocaml_version; rsync_path; sandbox_config } =
      `Assoc
        [
          ("ocaml_version", `String (Ocaml_version.to_string ocaml_version));
          ("rsync_path", `String rsync_path);
          ( "sandbox_config",
            `String
              (Sandbox.sexp_of_config sandbox_config |> Sexplib0.Sexp.to_string)
          );
        ]

    let digest t = Yojson.Safe.to_string (to_yojson t)
  end

  module Value = Current.String

  let id = "obuilder-build"

  let run ~job ocaml_version rsync_path sandbox_config =
    let open Lwt.Syntax in
    let ( / ) = Filename.concat in
    let* (Obuilder.Store_spec.Store ((module Store), store)) =
      Obuilder.Store_spec.to_store Copy (`Rsync rsync_path)
    in
    let module Builder = Obuilder.Builder (Store) (Sandbox) (Fetcher) in
    let* sandbox =
      Sandbox.create ~state_dir:(Store.state_dir store / "runc") sandbox_config
    in
    let builder = Builder.v ~store ~sandbox in
    let log tag msg =
      match tag with
      | `Heading ->
          Current.Job.log job "%a@." Fmt.(styled (`Fg (`Hi `Blue)) string) msg
      | `Note ->
          Current.Job.log job "%a@." Fmt.(styled (`Fg `Yellow) string) msg
      | `Output -> Current.Job.log job "%s%!" msg
    in
    let context = Obuilder.Context.v ~log ~src_dir:"." () in
    Current.Job.log job "Building base image for %a" Ocaml_version.pp
      ocaml_version;
    let+ res = Builder.build builder context (spec_file ocaml_version) in
    match res with
    | Error `Cancelled -> Error (`Msg "Cancelled")
    | (Error (`Msg _) | Ok _) as v -> v

  let build No_context job key =
    let { Key.ocaml_version; rsync_path; sandbox_config } = key in
    Current.Job.start job ~level:Current.Level.Mostly_harmless >>= fun () ->
    run ~job ocaml_version rsync_path sandbox_config >>!= fun s ->
    Lwt_result.return s

  let pp f key = Fmt.pf f "%s" (Key.digest key)
  let auto_cancel = false
end

module B = Current_cache.Make (Build_op)

let build ~ocaml_version ~rsync_path ~sandbox_config schedule =
  let open Current.Syntax in
  Current.component "%a" Ocaml_version.pp ocaml_version
  |> let> () = Current.return () in
     B.get ~schedule Build_op.No_context
       { Build_op.Key.ocaml_version; rsync_path; sandbox_config }
