# Check if go is installed
ifeq ($(shell command -v go 2> /dev/null),)
$(error "go is not installed. Please install Go from https://golang.org/dl/")
endif

GOBIN := $(shell go env GOPATH)/bin

.PHONY: init check-go-tools ksl-schema

init:
	@HASH=$$(git ls-remote https://github.com/project-kessel/ksl-schema-language.git HEAD | cut -f1) && \
	go install github.com/project-kessel/ksl-schema-language/cmd/ksl@$$HASH

check-go-tools:
	@echo "Checking required Go tools..."
	@if [ -f "$(GOBIN)/ksl" ]; then \
		echo "✓ ksl: installed"; \
	else \
		echo "✗ ksl: NOT installed (run 'make init')"; \
	fi


schemas/schema.zed: schemas/src/*.ksl
	$(GOBIN)/ksl -o schemas/schema.zed schemas/src/*.ksl

schema: schemas/schema.zed
