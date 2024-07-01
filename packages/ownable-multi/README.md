# Multi-Owner Process Ownership on AO

This package facilitates the development of AO processes that require the ability to

- manage ownership of the process with **multiple equal owners**
- gate access to handlers based on process ownership

## Features

1. An access control check based on an **emulated shared ownership** at the application level
2. Handler to get current owners
3. Adding / Removing owners
4. Ownership renouncement via the AO [_Ownership Renounce Manager_](https://github.com/Autonomous-Finance/ao-ownership-renounce-manager)

## Installation

```lua
APM.install('@af/ownable-multi')
```

## Usage

1. Require the `ownable` module in your Lua script
2. Execute `ownable.multi(initialOwners)` with an optional initial list of owner accounts

```lua
-- process.lua

local ownableMulti = require("@af/ownable-multi")

ocal initialOwners = { 'abc1xyz', 'def2zyx'} -- other owners besides the process deployer
ownableMulti.load(initialOwners)
```

## Conflict Considerations

⚠️ ❗️ Be mindful of potential conflicts in terms of **global state** and the **`Handlers.list`**

Both your application code and other packages you install via APM, can potentially conflict with this package.

So, if you decide to use this package, consider the following

```lua
_G.OWNERSHIP_RENOUNCER_PROCESS

Handlers.list = {
  -- ...
  
  -- the custom eval handlers MUST REMAIN AT THE TOP of the Handlers.list
  { 
    name = "customEvalMatchPositive",
    -- ... 
  },
  { 
    name = "customEvalMatchNegative",
    -- ... 
  },
  { 
    name = "getOwners", 
    -- ... 
  },
  { 
    name = "addOwner", 
    -- ... 
  },
  { 
    name = "removeOwner", 
    -- ... 
  },
  { 
    name = "renounceOwnership", 
    -- ... 
  }
  -- ...
}
```

## How It Works

The native `Owner` changes on each `Eval` performed by one of the IDs in `Owners`.

This approach allows for whitelisted wallets to interact with the process via the aos CLI as if they are regular owners
   - Results from query `Eval`'s like `aos> Owner` are displayed immediately in the CLI
   - The last `Eval` sender becomes the current process Owner
   - The process interface can be shut down and reopened by any whitelisted account regardless of who the last `Eval` sender was

The **initial Owner** (that spawned the process) is always included in the whitelist, but **can be removed** by another account from `Owners`.