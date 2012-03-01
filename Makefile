build:
	node node_modules/coffee-script/bin/coffee -o . -c src

test: build
	node node_modules/jasmine-node/bin/jasmine-node --coffee test

.PHONY: build test