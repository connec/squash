build:
	coffee -o . -c src

test:
	jasmine-node --coffee test

.PHONY: build test