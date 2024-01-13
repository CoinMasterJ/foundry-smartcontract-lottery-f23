-include .env

.PHONY: all test deploy

ANVIL_PRIVATE_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo "make deploy [ARGS=...]"

build:; forge build
NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(ANVIL_PRIVATE_KEY)  --broadcast

ifeq ($(findstring --network fuji,$(ARGS)), --network fuji)
	NETWORK_ARGS := --rpc-url $(AVAX_FUJI_RPC) --private-key $(PRIVATE_KEY) --broadcast --verifier-url 'https://api.routescan.io/v2/network/testnet/evm/43113/etherscan' --etherscan-api-key "verifyContract" -vvvv
endif

anvil:
	anvil:; -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

deploy:
	@forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS)
