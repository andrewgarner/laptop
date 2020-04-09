PWD ?= $(shell pwd)

.PHONY: test

test:
	docker run --rm -it -v $(PWD):/workdir:ro -w /workdir koalaman/shellcheck-alpine shellcheck install.sh
