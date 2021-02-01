#!/bin/sh 
echo "Install Lock-free Homebrew"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/patricoferris/install/disable-locking/install.sh)"

echo "Install Opam 2.0 (branch) and 2.1 (master)"
git clone -b 2.0 git://github.com/ocaml/opam ./opam
cd ./opam && make cold && mkdir -p ~/local/bin && cp ./opam ~/local/bin/opam-2.0 && chmod a+x ~/local/bin/opam-2.0
rm -rf ./opam && git clone -b master git://github.com/ocaml/opam ./opam
cd ./opam && make cold && mkdir -p ~/local/bin && cp ./opam ~/local/bin/opam-latest && chmod a+x ~/local/bin/opam-latest && rm -rf ../opam

echo "Default link 2.0 to opam"
ln ~/local/bin/opam-2.0 ~/local/bin/opam

echo "Check opam"
opam --version
