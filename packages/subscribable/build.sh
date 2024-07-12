#!/bin/bash

if [[ "$(uname)" == "Linux" ]]; then
    BIN_PATH="$HOME/.luarocks/bin"
else
    BIN_PATH="/opt/homebrew/bin"
fi

# 1. ------ build package source
cd src

$BIN_PATH/luacheck main.lua pkg-api.lua storage-vanilla.lua storage-db.lua
$BIN_PATH/amalg.lua -s main.lua -o ../build/main.lua pkg-api storage-vanilla storage-db

# prepend resets to the output file
cat reset.lua | cat - ../build/main.lua > temp && mv temp ../build/main.lua

# make package build available to example
cp ../build/main.lua ../example/subscribable.lua


# 2. ------ build example source
cd ../example

$BIN_PATH/luacheck example.lua example-db.lua
$BIN_PATH/amalg.lua -s example.lua -o ../build/example.lua subscribable
$BIN_PATH/amalg.lua -s example-db.lua -o ../build/example-db.lua subscribable

# prepend resets to the output file
cat reset.lua | cat - ../build/example-db.lua > temp && mv temp ../build/example-db.lua
