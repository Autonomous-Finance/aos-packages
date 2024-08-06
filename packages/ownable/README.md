# ownable

## Simple Process Ownership & Access Control on AO

This package facilitates the development of AO processes that require the ability to

- manage ownership of the process
- gate access to handlers based on process ownership

The aim is to make it possible for builders to simply "plug it in", much like one would extend a smart contract in Solidity.

## Features

1. An access control check based on **native process ownership** on AO.
3. Handler to get current owner
4. Ownership transfer
5. Ownership renouncement via the AO [_Ownership Renounce Manager_](https://github.com/Autonomous-Finance/ao-ownership-renounce-manager)

### Owner vs Self

A **direct interaction** of the owner with their process can occur in multiple ways
- message sent via *aoconnect* in a node script
- message sent via the *ArConnect* browser extension (aoconnect-bsed)
- message sent through the [AO.LINK UI](https://ao.link), using the "Write" tab on a process page (aoconnect-based)

Unlike on EVM systems, where the owner interacts with the smart contract by sending a transaction directly to it, on AO we also have an **indirect interaction** between owner and process. It is common for an owner to interact with their process by opening it in AOS. Calling a handler of the process through an AOS evaluation like

```lua
Send({Target = ao.id, Action = 'Protected-Handler'})
```

will actually result in an `Eval` message with this code, where the **sender is the process itself**.

This is why, additionally to the expected `Ownable.onlyOwner()`, we've included `Ownable.onlyOwnerOrSelf()` as an option for gating your handlers.

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
      
      Ownable.transferOwnership(newOwner) -- performs the transfer of ownership
      
      Ownable.onlyOwner(msg) -- acts like a modifier in Solidity (errors on negative result)

      Ownable.onlyOwnerOrSelf(msg) -- acts like a modifier in Solidity (errors on negative result)
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

or override handle functions
```lua
-- handle for "ownable.Transfer-Ownership"
function(msg)
  -- same as before
  Ownable.onlyOwner(msg)
  -- ADDITIONAL condition
  assert(isChristmasEve(msg.Timestamp))
  -- same as before
  Ownable.handleTransferOwnership(msg)
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
