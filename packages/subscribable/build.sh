#!/bin/bash

if [[ "$(uname)" == "Linux" ]]; then
    BIN_PATH="$HOME/.luarocks/bin"
else
    BIN_PATH="/opt/homebrew/bin"
fi

$BIN_PATH/luacheck src/main.lua src/subscriptions.lua src/utils.lua
$BIN_PATH/amalg.lua -s src/main.lua -o build/main.lua src.subscriptions src.utils
npx aoform apply
