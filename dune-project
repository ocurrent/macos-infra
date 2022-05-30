(lang dune 2.9)

(name macos-base-image)

(generate_opam_files true)

(source
 (github patricoferris/macos-infra))

(license MIT)

(authors "Patrick Ferris")

(maintainers "patrick@sirref.org")

(package
 (name macos-base-image)
 (synopsis "OCaml library for macOS OBuilder images")
 (description "This library and executable provides a way to build OCaml base images for macOS.")
 (depends
   obuilder
   obuilder-spec
   ocaml-version
   logs
   fmt))