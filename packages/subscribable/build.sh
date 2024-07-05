#!/bin/bash

if [[ "$(uname)" == "Linux" ]]; then
    BIN_PATH="$HOME/.luarocks/bin"
else
    BIN_PATH="/opt/homebrew/bin"
fi

cd src

$BIN_PATH/luacheck main.lua subscriptions.lua utils.lua
$BIN_PATH/amalg.lua -s main.lua -o ../build/main.lua subscriptions utils

# prepend resets to the output file
cat reset.lua | cat - ../build/main.lua > temp && mv temp ../build/main.lua

cp ../build/main.lua ../example/subscribable.lua

cd ../example

$BIN_PATH/luacheck example.lua
$BIN_PATH/amalg.lua -s example.lua -o ../build/example.lua subscribable

# prepend resets to the output file
cat reset.lua | cat - ../build/example.lua > temp && mv temp ../build/example.lua