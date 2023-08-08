SHELL := /bin/bash

help:
	@grep -E '^[ a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
	awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

ifndef LIGO
LIGO=docker run --platform linux/amd64 --rm -v "$(PWD)":"$(PWD)" -w "$(PWD)" ligolang/ligo:0.70.1
endif
# ^ use LIGO en var bin if configured, otherwise use Docker

project_root=--project-root .
# ^ required when using packages

compile = $(LIGO) compile contract $(project_root) ./src/$(1) -o ./compiled/$(2) $(3)
# ^ compile contract to michelson or micheline

test = $(LIGO) run test $(project_root) ./test/$(1)
# ^ run given test file

compile: ## compile contracts
	@if [ ! -d ./compiled ]; then mkdir ./compiled ; fi
	@echo "Compiling contracts..."
	@$(call compile,main.mligo,dao.tz)
	@$(call compile,main.mligo,dao.json,--michelson-format json)

clean: ## clean up
	@rm -rf compiled/*

install: ## install dependencies
	@if [ ! -f ./.env ]; then cp .env.dist .env ; fi
	@$(LIGO) install

compile-lambda: ## compile a lambda (F=./lambdas/empty_operation_list.mligo make compile-lambda)
# ^ helper to compile lambda from a file, used during development of lambdas
ifndef F
	@echo 'Please provide an init file (F=)'
else
	@$(LIGO) compile expression $(project_root) cameligo lambda_ --init-file $(F)
## ^ the lambda is expected to be bound to the name 'lambda_'
endif

pack-lambda: ## pack lambda expression (F=./lambdas/empty_operation_list.mligo make pack-lambda)
# ^ helper to get packed lambda and hash
ifndef F
	@echo 'Please provide an init file (F=)'
else
	@echo 'Packed:'
	@$(LIGO) run interpret $(project_root) 'Bytes.pack(lambda_)' --init-file $(F)
	@echo "Hash (sha256):"
	@$(LIGO) run interpret $(project_root) 'Crypto.sha256(Bytes.pack(lambda_))' --init-file $(F)
endif

.PHONY: test
test: ## run tests (SUITE=propose make test)
ifndef SUITE
	@$(call test,cancel.test.mligo)
	@$(call test,end_vote.test.mligo)
	@$(call test,execute.test.mligo)
	@$(call test,lock.test.mligo)
	@$(call test,propose.test.mligo)
	@$(call test,release.test.mligo)
	@$(call test,score.test.mligo)
	@$(call test,vote.test.mligo)
else
	@$(call test,$(SUITE).test.mligo)
endif
