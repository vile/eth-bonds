.PHONY: all update install build clean clean-git clean-coverage-report clean-lcov clean-slither clean-aderyn test-ext test coverage coverage-lcov slither aderyn script-deploy sudo-act

all: clean install build

### Core

update :; forge update

install :; foundryup && forge install foundry-rs/forge-std --no-commit && forge install vectorized/solady --no-commit

build :; forge build

### Clean

clean: clean-git clean-coverage-report clean-lcov clean-slither clean-aderyn

clean-git :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules

clean-coverage-report :; -rm -rf coverage-report

clean-lcov :; -rm -rf lcov.info

clean-slither :; -rm -rf slither.txt

clean-aderyn :; -rm -rf aderyn-report.md

### Testing & Coverage

test-ext: test coverage-lcov slither aderyn

test :; forge test

coverage :; forge coverage

coverage-lcov :; forge coverage --report lcov && genhtml -o report --branch-coverage lcov.info && mv report coverage-report

slither :; -slither . --exclude-dependencies > slither.txt 2>&1

aderyn :; aderyn . && mv report.md aderyn-report.md

### Scope

scopefile :; @tree ./src/ | sed 's/└/#/g' | awk -F '── ' '!/\.sol$$/ { path[int((length($$0) - length($$2))/2)] = $$2; next } { p = "src"; for(i=2; i<=int((length($$0) - length($$2))/2); i++) if (path[i] != "") p = p "/" path[i]; print p "/" $$2; }' > scope.txt

scope :; tree ./src/ | sed 's/└/#/g; s/──/--/g; s/├/#/g; s/│ /|/g; s/│/|/g'

### Deploy

script-deploy :; forge script script/DeployBond.s.sol -vvvvv

### Local Workflows

# Example usage:
#	- make sudo-act ACTION=workflow_dispatch
sudo-act :; sudo env "PATH=$$PATH" act $(ACTION) $(FLAGS)
