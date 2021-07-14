#!/bin/sh 

echo "Installing vanilla homebrew"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# echo "Install Lock-free Homebrew (maybe needed for parallel support)"
# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/patricoferris/install/disable-locking/install.sh)"

echo "Install Opam 2.0 (branch) and 2.1 (master)"
git clone -b 2.0-c++20-compat git://github.com/patricoferris/opam ./opam
cd ./opam && make cold && mkdir -p ~/local/bin && cp ./opam ~/local/bin/opam-2.0 && chmod a+x ~/local/bin/opam-2.0 && cd ../ && rm -rf ./opam 
git clone -b master git://github.com/ocaml/opam ./opam
cd ./opam && make cold && mkdir -p ~/local/bin && cp ./opam ~/local/bin/opam-latest && chmod a+x ~/local/bin/opam-latest && cd ../ && rm -rf ./opam

echo "Default link 2.0 to opam"
ln ~/local/bin/opam-2.0 ~/local/bin/opam

echo "Check opam"
opam --version

# Thanks Kate -- no opam init called just yet :)
echo "Updating the .obuilder_profile.sh to pre-init OCaml"

echo 'export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin' >> ./.obuilder_profile.sh

case "$USER" in
homebrew-*) echo 'export PATH=/opt/homebrew/bin:/opt/homebrew/sbin:$PATH' >> ./.obuilder_profile.sh;; # /opt is used for homebrew on macOS/arm64
*) echo "Distribution not supported"; exit 1;;
esac

case "\$USER" in
homebrew-ocaml-4.12) echo 'export PATH=/Users/administrator/ocaml/4.12.0/bin:$PATH' >> ./.obuilder_profile.sh;;
homebrew-ocaml-4.11) echo 'export PATH=/Users/administrator/ocaml/4.11.1/bin:$PATH' >> ./.obuilder_profile.sh;;
homebrew-ocaml-4.10) echo 'export PATH=/Users/administrator/ocaml/4.10.2/bin:$PATH' >> ./.obuilder_profile.sh;;
homebrew-ocaml-4.09) echo 'export PATH=/Users/administrator/ocaml/4.09.1/bin:$PATH' >> ./.obuilder_profile.sh;;
homebrew-ocaml-4.08) echo 'export PATH=/Users/administrator/ocaml/4.08.1/bin:$PATH' >> ./.obuilder_profile.sh;;
homebrew-ocaml-4.07) echo 'export PATH=/Users/administrator/ocaml/4.07.1/bin:$PATH' >> ./.obuilder_profile.sh;;
homebrew-ocaml-4.06) echo 'export PATH=/Users/administrator/ocaml/4.06.1/bin:$PATH' >> ./.obuilder_profile.sh;;
homebrew-ocaml-4.05) echo 'export PATH=/Users/administrator/ocaml/4.05.0/bin:$PATH' >> ./.obuilder_profile.sh;;
homebrew-ocaml-4.04) echo 'export PATH=/Users/administrator/ocaml/4.04.2/bin:$PATH' >> ./.obuilder_profile.sh;;
homebrew-ocaml-4.03) echo 'export PATH=/Users/administrator/ocaml/4.03.0/bin:$PATH' >> ./.obuilder_profile.sh;;
*) echo "Can't find the ocaml version"; exit 1;;
esac
