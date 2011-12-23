build:
	coffee -o . -c src

test: build
	jasmine-node --coffee test

.PHONY: build test