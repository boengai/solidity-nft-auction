include .env

PRIVATE_KEY := ${FOUNDRY_PRIVATE_KEY}
RPC_URL := ${FOUNDRY_RPC_URL}

clean-screen:
	@clear

submodule/init:
	@git submodule update --init --recursive

remappings:
	@forge remappings > remappings.txt

flatten:
	@for SOURCE in $(shell find ./src -name "*.sol") ; do \
		forge flatten --output $${SOURCE/src/flattened} $$SOURCE; \
	done;

test: test/all

test/all: clean-screen
	@forge test -vvv

test/all/gas-report: clean-screen
	@forge test \
		--gas-report
