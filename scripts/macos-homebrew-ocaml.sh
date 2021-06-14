#!/bin/sh 

echo "Installing vanilla homebrew"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# echo "Install Lock-free Homebrew (maybe needed for parallel support)"
# /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/patricoferris/install/disable-locking/install.sh)"

echo "Install Opam 2.0 (branch) and 2.1 (master)"
git clone -b 2.0 git://github.com/ocaml/opam ./opam
cd ./opam && make cold && mkdir -p ~/local/bin && cp ./opam ~/local/bin/opam-2.0 && chmod a+x ~/local/bin/opam-2.0 && cd ../ && rm -rf ./opam 
git clone -b master git://github.com/ocaml/opam ./opam
cd ./opam && make cold && mkdir -p ~/local/bin && cp ./opam ~/local/bin/opam-latest && chmod a+x ~/local/bin/opam-latest && cd ../ && rm -rf ./opam

echo "Default link 2.0 to opam"
ln ~/local/bin/opam-2.0 ~/local/bin/opam

echo "Check opam"
opam --version

# Thanks Kate -- no opam init called just yet :)
echo "Updating the bash_profile to pre-init OCaml"
cat >> ./.bash_profile <<- EOM
  case "'$USER'" in 
  *-ocaml-4.11) export PATH="/Users/administrator/ocaml/4.11.1/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:/Library/Frameworks/Mono.framework/Versions/Current/Commands:/usr/local/bin";;
  *-ocaml-4.10) export PATH="/Users/administrator/ocaml/4.10.2/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:/Library/Frameworks/Mono.framework/Versions/Current/Commands:/usr/local/bin";;
  *-ocaml-4.09) export PATH="/Users/administrator/ocaml/4.09.1/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:/Library/Frameworks/Mono.framework/Versions/Current/Commands:/usr/local/bin";;
  *-ocaml-4.08) export PATH="/Users/administrator/ocaml/4.08.1/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:/Library/Frameworks/Mono.framework/Versions/Current/Commands:/usr/local/bin";;
  *-ocaml-4.07) export PATH="/Users/administrator/ocaml/4.07.1/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:/Library/Frameworks/Mono.framework/Versions/Current/Commands:/usr/local/bin";;
  *-ocaml-4.06) export PATH="/Users/administrator/ocaml/4.06.1/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:/Library/Frameworks/Mono.framework/Versions/Current/Commands:/usr/local/bin";;
  *-ocaml-4.05) export PATH="/Users/administrator/ocaml/4.05.0/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:/Library/Frameworks/Mono.framework/Versions/Current/Commands:/usr/local/bin";;
  *-ocaml-4.04) export PATH="/Users/administrator/ocaml/4.04.2/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:/Library/Frameworks/Mono.framework/Versions/Current/Commands:/usr/local/bin";;
  *-ocaml-4.03) export PATH="/Users/administrator/ocaml/4.03.0/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:/Library/Frameworks/Mono.framework/Versions/Current/Commands:/usr/local/bin";;
  *) echo "Wrong user name. Can't find the ocaml version"; exit 1;;
  esac
EOM
