#!/bin/bash
if [[ "$(uname)" == "Linux" ]]; then
    BIN_PATH="$HOME/.luarocks/bin"
else
    BIN_PATH="/opt/homebrew/bin"
fi

$BIN_PATH/luacheck main.lua
$BIN_PATH/amalg.lua -s main.lua -o build/main.lua