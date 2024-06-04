# ETH Bonds

[![solidity - v0.8.25](https://img.shields.io/badge/solidity-v0.8.25-2ea44f?logo=solidity)](https://soliditylang.org/)
[![Foundry - Latest](https://img.shields.io/static/v1?label=Foundry&message=latest&color=black&logo=solidity&logoColor=white)](https://book.getfoundry.sh/)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-%23FE5196?logo=conventionalcommits&logoColor=white)](https://conventionalcommits.org)

## About

A simple ownable contract that allows for on-chain keeping of "bonds," denominated in Ether.
The usage of bonds is not specific, but, for example, can be used to whitelist wallets to interact with dApps (e.g., [LayerZero Sybil Reporting](https://x.com/LayerZero_Labs/status/1794186650223878240)).

## Getting Started

### Requirements

1. Git - [Install Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
   1. Check if you have Git installed with `git --version`
2. Foundry - [Install Foundry](https://getfoundry.sh/)
   1. Check if you have Foundry installed with `forge --version`

#### Optional

1. Python - Install [Python](https://docs.python.org/3/using/unix.html) (see [pyenv](https://github.com/pyenv/pyenv))
   1. Check if you have Python installed with `python --version`
   2. Required for Slither
2. Slither - [Install Slither](https://github.com/crytic/slither?tab=readme-ov-file#how-to-install) (preferably with [pipx](https://github.com/pypa/pipx))
   1. Check if you have Slither installed with `slither --version`
3. Rust - Install [Rust](https://www.rust-lang.org/tools/install)
   1. Check if you have Rust installed with `rustc --version`
   2. Required for Aderyn
4. Aderyn - Install [Aderyn](https://github.com/Cyfrin/aderyn#installation)
   1. Check if you have Aderyn installed with `aderyn --version`
5. 4naly3er - Install [4naly3er](https://github.com/Picodes/4naly3er)
   1. This is an external tool, ensure to export a scope file, `make scopefile`, before use

#### Development

1. Act - [Install Act](https://nektosact.com/installation/index.html#pre-built-artifacts)
   1. Check if you have Act installed with `act --version`
   2. Refer to this project's [Makefile](./Makefile) (`sudo-act`) for usage
2. Markdownlint - [Install Markdownlint](https://marketplace.visualstudio.com/items?itemName=DavidAnson.vscode-markdownlint)

## Installation

```bash
git clone https://github.com/vile/eth-bonds.git
cd eth-bonds
make
```

## Usage

### Testing

```bash
make test
make test-ext # Includes coverage report, slither, & aderyn
```

Run individual tests with:

```bash
forge test --mt test_name -vvvvv
```

### Deploying

#### Keystore

Ensure you have your intended deployment wallet imported as a keystore for Foundry.
If not, create a new wallet using `cast`, and import it as a keystore.

```bash
cast wallet list
cast wallet new
cast wallet import [your_new_wallet]
cast wallet address --account [your_new_wallet]
```

### Environment Variables

Then, input your keystore name and wallet address in `.env`.
In addition to this, include your RPC URL and Etherscan API key.

```bash
mv .env.example .env
```

Futhermore in `.env`, include deployment parameters.
If you are unsure what the deployment parameters mean (or intend to do), refer to the `.env` comments and the NatSpec of [Bond's constructor](./src/Bond.sol).

#### Deploy Script

Finally, push a live deployment (or dryrun):

```bash
make script-deploy-live # OR
make script-deploy-dry
```
