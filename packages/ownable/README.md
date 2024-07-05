# ownable

## Simple Process Ownership & Access Control on AO

This package facilitates the development of AO processes that require the ability to

- manage ownership of the process
- gate access to handlers based on process ownership

The aim is to make it possible for builders to simply "plug it in", much like one would extend a smart contract in Solidity.

## Features

1. An access control check based on **native process ownership** on AO. 
2. Handler to get current owner
3. Ownership transfer
4. Ownership renouncement via the AO [_Ownership Renounce Manager_](https://github.com/Autonomous-Finance/ao-ownership-renounce-manager)

## Installation

```lua
APM.install('@autonomousfinance/ownable')
```

## Usage

Require this package in your Lua script. The resulting table contains the package API. The `require` statement also adds package-specific handlers into the `_G.Handlers.list` of your process.

```lua
-- process.lua

Ownable = require("@autonomousfinance/ownable")

  --[[ 
    now you have 
    1. additional handlers added to Handlers.list
    2. the ability to use the ownable API
      
      ownable.transferOwnership(newOwner) -- performs the transfer of ownership
      
      ownable.onlyOwner(msg) -- acts like a modifier in Solidity (errors on negative result)

      ...
  ]]

```

### No global state pollution

Except for the `_G.Handlers.list`, the package affects nothing in the global space of your project. For best upgradability, we recommend assigning the required package to a global variable of your process.

## Overriding Functionality

Similarly to extending a smart contract in Solidity, using this package allows builders to change the default functionality as needed.

### 1. You can override handlers added by this package.

Either replace the handler entirely
```lua
Handlers.add(
  'ownable.Transfer-Ownership',
  -- your matcher ,
  -- your handle function
)
```

or override handleFunctions
```lua
local originalHandleTransferOwnership = Ownable.handleTransferOwnership
Ownable.handleTransferOwnership = function(msg)
  -- same as before
  Ownable.onlyOwner(msg)
  -- ADDITIONAL condition
  assert(isChristmasEve(msg.Timestamp))
  -- same as before
  originalHandleTransferOwnership
end
```

### 2. You can override more specific API functions of this package.
```lua
local originalTransferOwnership = Ownable.transferOwnership
Ownable.transferOwnership = function(newOwner)
  -- same as before
  originalTransferOwnership(newOwner)
  -- your ADDITIONAL logic
  ao.send({Target = AGGREGATOR_PROCESS, Action = "Owner-Changed", ["New-Owner"] = newOwner})
end
```

## Conflicts in the Global Space

⚠️ ❗️ If overriding handlers is not something you need, be mindful of potential conflicts in terms of the **`Handlers.list`**

Both your application code and other packages you install via APM, can potentially conflict with this package. Consider the following handlers as reserved by this package.

```lua
Handlers.list = {
  -- ...
  { 
    name = "ownable.getOwner", 
    -- ... 
  },
  { 
    name = "ownable.transferOwnership", 
    -- ... 
  },
  { 
    name = "ownable.renounceOwnership", 
    -- ... 
  }
  -- ...
}
```
