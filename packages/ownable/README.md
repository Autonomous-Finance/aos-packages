# ownable

## Simple Process Ownership & Access Control on AO

This package facilitates the development of AO processes that require the ability to

- manage ownership of the process
- gate access to handlers based on process ownership

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

1. Require the `ownable` module in your Lua script
2. Execute `ownable.load()`

These steps will add the necessary global state and Handlers.

```lua
-- process.lua

local ownable = require("@autonomousfinance/ownable")

ownable.load()
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

