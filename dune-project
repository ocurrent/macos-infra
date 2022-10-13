(lang dune 3.0)

(name macos-base-image)

(generate_opam_files true)

(source
 (github ocurrent/macos-infra))

(license MIT)

(authors "Patrick Ferris")

(maintainers "timmcgil@gmail.com")

(package
 (name macos-base-image)
 (synopsis "OCaml library for macOS OBuilder images")
 (description "This library and executable provides a way to build OCaml base images for macOS.")
 (depends
  (ocaml (>= 4.12.0))
   obuilder
   obuilder-spec
   ocaml-version
   current
   current_docker
   current_web
   dockerfile
   logs
   fmt))