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

## Usage

This package can be used via APM installation through `aos` or via a pre-build APM download into your project directory.

### APM download & require locally

Install `apm-tool` on your system. This cli tool allows you to download APM packages into your lua project.

```shell
npm i -g apm-tool
```

Downlad the package into your project as a single lua file:

```shell
cd your/project/directory
apm-tool download ownable-multi
cp apm_modules/@autonomousfinance/ownable-multi/main.lua ./ownable-multi.lua
```

Require the file locally from your main process file. 

```lua
Ownable = require("ownable-multi") ({
  initialOwners = -- ... your initial owners, besides the main process Owner
})
```

The code in `example-process-once.lua` and `example-process-upgradable.lua` demonstrates how to achieve this. 

📝 Keep in mind, with this approach you will eventually need to amalgamate your `example-process.lua` and `ownable-multi.lua` into a single lua file that can be `.load`ed into your process via AOS. See `package/subscribable/build.sh` for an example of how to achieve this.

### APM install & require from APM

Connect with your process via `aos`. Perform the **steps 1 & 2 from your AOS client terminal**.

1. Install APM in your process

```lua
.load client-tool.lua
```

2. Install this package via APM

```lua
APM.install('@autonomousfinance/ownable-multi')
```

3. Require this package in your Lua script. The resulting table contains the package API. The `require` statement also adds package-specific handlers into the `_G.Handlers.list` of your process.

```lua
local initialOwners = { 'abc1xyz', 'def2zyx'} -- other owners besides the process deployer
Ownable = require "@autonomousfinance/ownable-multi" ({
  initialOwners = initialOwners
})
```

### After requiring

After the package is required into your main process, you have

 1. additional handlers added to Handlers.list
 2. the ability to use the `ownable-multi` API

```lua
-- ownable API

Ownable.onlyOwner(msg) -- acts like a modifier in Solidity (errors on negative result)

Ownable.onlyOwnerOrSelf(msg) -- acts like a modifier in Solidity (errors on negative result)

Ownable.addOwner(newOwner) -- performs the addition of a new owner

Ownable.getOwnersArray() -- returns the current owners as an array
```

#### No global state pollution

Except for the `_G.Handlers.list`, the package affects nothing in the global space of your project. The state needed to manage multiple owners is **encapsulated in the package module**.
However, for upgradability we recommend assigning the required package to a global variable of your process (see below).

## Upgrading your process

You may want your lua process to be upgradable, which includes the ability to upgrade this package as it is used by your process. 

In order to make this possible, this package gives you the option to `require` it as an upgrade.
```lua
Ownable = require "@autonomousfinance/ownable-multi" ()
```
When doing that, the internal package state your process has been using so far (i.e. the multiple owners), will be "adopted" by the new version of package. This only works **if you are using `Ownable` as the name** for the global variable of the required package in your process.

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