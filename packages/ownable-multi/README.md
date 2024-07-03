# ownable-multi

## Multi-Owner Process Ownership & Access Control on AO

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
APM.install('@autonomousfinance/ownable-multi')
```

## Usage

1. Require the `ownable-multi` module in your Lua script
2. On this module, execute `.load(initialOwners)` with an optional initial list of owner accounts

```lua
-- process.lua

local ownableMulti = require("@autonomousfinance/ownable-multi")

ocal initialOwners = { 'abc1xyz', 'def2zyx'} -- other owners besides the process deployer
ownableMulti.load(initialOwners)
```

## Overriding & Conflict Considerations

You can override handlers added by this package. Just use
```lua
Handlers.add(<package_handler_name>)
```
in your own code, after you've executed 
```lua
ownable.load()
```

⚠️ ❗️ If overriding functionality is not something you need, be mindful of potential conflicts in terms of the **`Handlers.list`**

Both your application code and other packages you install via APM, can potentially conflict with this package.

So, if you decide to use this package, consider the following

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
    name = "ownable-multi.getOwners", 
    -- ... 
  },
  { 
    name = "ownable-multi.addOwner", 
    -- ... 
  },
  { 
    name = "ownable-multi.removeOwner", 
    -- ... 
  },
  { 
    name = "ownable-multi.renounceOwnership", 
    -- ... 
  }
  -- ...
}
```

## How It Works

The native `Owner` changes on each `Eval` performed by one of the IDs in `OwnableMulti_Owners`.

This approach allows for whitelisted wallets to interact with the process via the aos CLI as if they are regular owners
   - Results from query `Eval`'s like `aos> Owner` are displayed immediately in the CLI
   - The last `Eval` sender becomes the current process Owner
   - The process interface can be shut down and reopened by any whitelisted account regardless of who the last `Eval` sender was

The **initial Owner** (that spawned the process) is always included in the whitelist, but **can be removed** by another account from `OwnableMulti_Owners`.