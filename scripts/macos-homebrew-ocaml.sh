#!/bin/sh 

set -e

# Required as the access to /tmp is forbidden
export TMPDIR=$(getconf DARWIN_USER_TEMP_DIR)

echo "Installing vanilla homebrew"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# echo "Install Lock-free Homebrew (maybe needed for parallel support)"
# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/patricoferris/install/disable-locking/install.sh)"

echo "Install Opam 2.0 and 2.1"
git clone -b 2.0-c++20-compat git://github.com/patricoferris/opam ./opam
cd ./opam && make cold && mkdir -p ~/local/bin && cp ./opam ~/local/bin/opam-2.0 && chmod a+x ~/local/bin/opam-2.0 && cd ../ && rm -rf ./opam 
git clone -b 2.1 git://github.com/ocaml/opam ./opam
cd ./opam && make CONFIGURE_ARGS=--with-0install-solver cold && mkdir -p ~/local/bin && cp ./opam ~/local/bin/opam-2.1 && chmod a+x ~/local/bin/opam-2.1 && cd ../ && rm -rf ./opam

echo "Default link 2.0 to opam"
ln ~/local/bin/opam-2.0 ~/local/bin/opam

echo "Check opam"
opam --version

echo "Updating the .obuilder_profile.sh to pre-init OCaml"

echo 'export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin' >> ./.obuilder_profile.sh

case "$USER" in
macos-homebrew-*) echo 'export PATH=/opt/homebrew/bin:/opt/homebrew/sbin:$PATH' >> ./.obuilder_profile.sh;; # /opt is used for homebrew on macOS/arm64
*) echo "Distribution not supported"; exit 1;;
esac

case "\$USER" in
macos-homebrew-ocaml-4.12) echo 'export PATH=/Users/administrator/ocaml/4.12.0/bin:$PATH' >> ./.obuilder_profile.sh;;
macos-homebrew-ocaml-4.11) echo 'export PATH=/Users/administrator/ocaml/4.11.1/bin:$PATH' >> ./.obuilder_profile.sh;;
macos-homebrew-ocaml-4.10) echo 'export PATH=/Users/administrator/ocaml/4.10.2/bin:$PATH' >> ./.obuilder_profile.sh;;
macos-homebrew-ocaml-4.09) echo 'export PATH=/Users/administrator/ocaml/4.09.1/bin:$PATH' >> ./.obuilder_profile.sh;;
macos-homebrew-ocaml-4.08) echo 'export PATH=/Users/administrator/ocaml/4.08.1/bin:$PATH' >> ./.obuilder_profile.sh;;
macos-homebrew-ocaml-4.07) echo 'export PATH=/Users/administrator/ocaml/4.07.1/bin:$PATH' >> ./.obuilder_profile.sh;;
macos-homebrew-ocaml-4.06) echo 'export PATH=/Users/administrator/ocaml/4.06.1/bin:$PATH' >> ./.obuilder_profile.sh;;
macos-homebrew-ocaml-4.05) echo 'export PATH=/Users/administrator/ocaml/4.05.0/bin:$PATH' >> ./.obuilder_profile.sh;;
macos-homebrew-ocaml-4.04) echo 'export PATH=/Users/administrator/ocaml/4.04.2/bin:$PATH' >> ./.obuilder_profile.sh;;
macos-homebrew-ocaml-4.03) echo 'export PATH=/Users/administrator/ocaml/4.03.0/bin:$PATH' >> ./.obuilder_profile.sh;;
*) echo "Can't find the ocaml version"; exit 1;;
esac

echo "Setting up opam"

git clone git://github.com/ocaml/opam-repository.git

opam init -k git -a ./opam-repository
opam install -y opam-depext

echo 'export OPAMYES=1' >> ./.obuilder_profile.sh
echo 'export OPAMCONFIRMLEVEL=unsafe-yes' >> ./.obuilder_profile.sh
echo 'export OPAMERRLOGLEN=0' >> ./.obuilder_profile.sh
echo 'export OPAMPRECISETRACKING=1' >> ./.obuilder_profile.sh
