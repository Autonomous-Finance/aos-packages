# ownable-multi

## Multi-Owner Process Ownership & Access Control on AO

This package facilitates the development of AO processes that require the ability to

- manage ownership of the process with **multiple equal owners**
- gate access to handlers based on process ownership

The aim is to make it possible for builders to simply "plug it in", much like one would extend a smart contract in Solidity.

## Features

1. An access control check based on an **emulated shared ownership** at the application level
2. Handler to get current owners
3. Adding / Removing owners
4. Ownership renouncement via the AO [_Ownership Renounce Manager_](https://github.com/Autonomous-Finance/ao-ownership-renounce-manager)

## Installation

```lua
APM.install('@autonomousfinance/ownable-multi')
```

## Usage

Require this package in your Lua script. The resulting table contains the package API. The `require` statement also adds package-specific handlers into the `_G.Handlers.list` of your process.

```lua
-- process.lua

local initialOwners = { 'abc1xyz', 'def2zyx'} -- other owners besides the process deployer
Ownable = require "@autonomousfinance/ownable-multi" ({
  initial = true,
  initialOwners = initialOwners
})

--[[ 
  now you have 
  1. additional handlers added to Handlers.list
  2. the ability to use the ownable-multi API

    Ownable.onlyOwner(msg) -- acts like a modifier in Solidity (errors on negative result)

    Ownable.addOwner(newOwner) -- performs the addition of a new owner

    Ownable.getOwnersArray() -- returns the current owners as an array

    ...
]]
```

### No global state pollution

Except for the `_G.Handlers.list`, the package affects nothing in the global space of your project. The state needed to manage multiple owners is **encapsulated in the package module**.
However, for upgradability we recommend assigning the required package to a global variable of your process (see below).

## Upgrading your process

You may want your lua process to be upgradable, which includes the ability to upgrade this package as it is used by your process. 

In order to make this possible, this package gives you the option to `require` it as an upgrade.
```lua
Ownable = require "@autonomousfinance/ownable-multi"({
  initial = false,
  existing = Ownable
})
```
When doing that, you **pass in the previously used package module**, such that all the internal package state your process has been using so far, can be "adopted" by the new version of package.

An example of this can be found in `example-process-upgradable.lua`.

## Overriding Functionality

Similarly to extending a smart contract in Solidity, using this package allows builders to change the default functionality as needed.

### 1. You can override handlers added by this package.

Either replace the handler entirely
```lua
Handlers.add(
  'ownable-multi.Add-Owner',
  -- your custom matcher,
  -- your custom handle function
)
```

or override handle functions
```lua
-- handle for "ownable-multi.Add-Owner"
function(msg)
  -- same as before
  Ownable.onlyOwner(msg)
  -- ADDITIONAL condition
  assert(isChristmasEve(msg.Timestamp))
  -- same as before
  Ownable.handleAddOwner(msg)
end
```

### 2. You can override more specific API functions of this package.
```lua
local originalAddOwner = Ownable.addOwner
Ownable.addOwner = function(newOwner)
  -- same as before
  originalAddOwner(newOwner)
  -- your ADDITIONAL logic
  ao.send({Target = AGGREGATOR_PROCESS, Action = "Owner-Added", ["New-Owner"] = newOwner})
end
```

## Conflicts in the Global Space

⚠️ ❗️ If overriding functionality is not something you need, be mindful of potential conflicts in terms of the **`Handlers.list`**

Both your application code and other packages you install via APM, can potentially conflict with this package. Consider the following handlers as reserved by this package.

```lua
Handlers.list = {
  -- ...

  -- the custom eval handlers MUST REMAIN AT THE TOP of the Handlers.list
  { 
    name = "ownable-multi.customEvalMatchPositive",
    -- ... 
  },
  { 
    name = "ownable-multi.customEvalMatchNegative",
    -- ... 
  },
  { 
    name = "ownable-multi.Get-Owners", 
    -- ... 
  },
  { 
    name = "ownable-multi.Add-Owner", 
    -- ... 
  },
  { 
    name = "ownable-multi.Remove-Owner", 
    -- ... 
  },
  { 
    name = "ownable-multi.Renounce-Ownership", 
    -- ... 
  }
  -- ...
}
```

Also, keep in mind that the code in this package will update your process' `_G.Owner` in order to achieve the desired behaviour.

## How It Works

This explanation assumes that you've named the required package `ownable`, as in 
```lua
Ownable = require "@autonomousfinance/ownable-multi" ({...})
```

The native `_G.Owner` changes on each `Eval` performed by one of the IDs in `ownable.Owners`.

This approach allows for whitelisted wallets to interact with the process via the aos CLI as if they are regular owners
   - Results from query `Eval`'s like `aos> Owner` are displayed immediately in the CLI
   - The last `Eval` sender becomes the current process Owner
   - The process interface can be shut down and reopened by any whitelisted account regardless of who the last `Eval` sender was

The **initial Owner** (that spawned the process) is always included in the whitelist, but **can be removed** by another account from `ownable.Owners`.