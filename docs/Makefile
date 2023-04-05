all: fuse.svg

%.svg: %.txt
	# https://github.com/blampe/goat
	$$(go env GOPATH)/bin/goat -i $^ -o $@
