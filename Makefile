.PHONY: build test example

build:
	@MIX_ENV=prod mix escript.build

test:
	@mix test

example: build
	@cd test/example && ../../ereceipt -i input.csv -i input2.csv -i input3.csv -o ""
