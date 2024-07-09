# subscribable

## Subscription provider capabilities for an AO process

This package facilitates the development of AO processes that require the ability to register subscribers for specific events and dispatch messages to them. Events are like topics in the pub-sub paradigm, but they allow for parameterization.

The package comes in two flavours:

1. The **vanilla** version is based on **simple Lua tables**.
2. The **DB** version is based on **sqlite3**, which is natively available on AO.

## Features

### Handlers

1. register subscriber
2. receive payment from subscriber (spam-protection / monetization) (only AOCRED)
3. get available topics
4. subscribe/unsubscribe a registered subscriber w/ specific events

### API

1. configure events w/ corresponding checks
2. functions to implement the above Handlers or your own variations
3. ability to register a process as whitelisted (not gated)
4. notify subscribers to given events
5. notify subscribers to given events with check
6. configure the payment token (not gated)

## Installation

```lua
APM.install('@autonomousfinance/subscribable')
```

## Usage

1. Require the `subscribable` package in your Lua script, while specifying whether you want the DB version.
2. Initially and whenever needed, execute `.configTopicsAndChecks()` to configure the supported events and corresponding checks.
3. In your process handlers, whenever event-relevant state changes have occurred, execute `.notifyTopic()` or `.checkNotifyTopic()` to dispatch notifications to subscribers.

```lua
-- process.lua

Subscribable = require "@autonomousfinance/subscribable" ({
  initial = true,
  useDB = false -- using the vanilla flavour
})

--[[ 
  now you have 
  1. additional handlers added to Handlers.list
  2. the ability to use the subscribable API

    - configTopicsAndChecks()
    - checkNotifyTopic()
    - checkNotifyTopics()
    - getRegisteredSubscriber()

    ...
]]

Counter = Counter or 0

Subscribable.configTopicsAndChecks({
  'even-counter',       -- topic name
  function()            -- a check function to determine if the event occurs & generate a notification payload
    if Counter % 2 == 0 then return true, {counter = Counter} end
    return false
  end
})

-- Updates to Counter
Handlers.add(
  'increment',
  Handlers.utils.hasMatchingTag("Action", "Increment"),
  function()
    -- state change
    Counter = Counter + 1
    -- notifications
    sub.checkNotifyTopic('even-counter') -- sends out notifications based on check and payload from the event check function you configured
  end
)
```

### Explicit vs. Fully Automated

For the sake of computational efficiency, we opted **against fully automated subscriber notifications**.

It would have been possible to design the package such that *any state change* results in a check for events and then proceeds to notify all subscribers. 

In contrast, `subscribable` gives you a framework to easily **configure** your custom event checks, in that you define

1. what events are supported
2. how the process state is checked to determine occurrence of a specific event

after which **you decide** where in your process handlers you want to perform checks for any given event. 

With the existing event checks being configured beforehand, your decision is coded declaratively - you can either 

1. `.checkNotifyTopic(<some_topic>)` - this checks for `<some_topic>` as configured by you. If positive, subscribers are then notified.
2. `.notifyTopic(<some_topic>)` - this notifies subscribers to `<some_topic>` without a check

With this approach you have more control over the occurrence of computation related to event checks and notification sending.

That being said, `subscribable` is designed to allow you to easily implement a **fully automated mechanism on top** of it, in your process which uses the package.


### Minimal global state pollution

The package affects nothing in the global space of your project, except for the `_G.Handlers.list` and `_G.DB` (if you opt for the *DB* flavour). The state needed for subscribable capabilities is **encapsulated in the package module**.

When opting for the *DB* flavour you'll probably be using sqlite in your own application code. For an efficient and yet convenient usage, this package makes `DB = sqlite3.open_memory()` a global singleton so that you wouldn't have to access it via the required package. Please keep in mind that this assignment only occurs once you require `subscribable` into your process.

For upgradability we recommend assigning the required package to a global variable of your process (see below).

## Upgrading your process

You may want your lua process to be upgradable, which includes the ability to upgrade this package as it is used by your process. 

In order to make this possible, this package gives you the option to `require` it as an upgrade.
```lua
Subscribable = require "@autonomousfinance/subscribable"({
  initial = false,
  existing = Subscribable
})
```
When doing that, you **pass in the previously used package module**, such that all the internal package state your process has been using so far, can be "adopted" by the new version of package.

Examples of this can be found in `example/example.lua` and `example/example-db.lua`.

❗️ The configuration for vanilla or db can only be used when you first require `subscribable`. Upgrades will not allow you to change flavour.

## Overriding Functionality

Similarly to extending a smart contract in Solidity, using this package allows builders to change the default functionality as needed.

### 1. You can override handlers added by this package.

Either replace the handler entirely
```lua
Handlers.add(
  'subscribable.Register-Subscriber',
  -- your custom matcher,
  -- your custom handle function
)
```

or override handleFunctions
```lua
-- handle for "ownable-multi.Register-Subscriber"
function(msg)
  -- ADDITIONAL condition
  assert(isChristmasEve(msg.Timestamp))
  -- same as before
  Subscribable.handleRegisterSubscriber
end
```

### 2. You can override more specific API functions of this package.
```lua
local originalRegisterSubscriber = Subscribable.registerSubscriber
Subscribable.registerSubscriber = function(processID)
  -- same as before
  originalRegisterSubscriber(processID)
  -- your ADDITIONAL logic
  ao.send({Target = AGGREGATOR_PROCESS, Action = "Subscriber-Registered", ["Process-ID"] = processID})
end
```

### 3. You can create new Handlers with available API functions of this package.
```lua
Handlers.add(
  "Register-Whitelisted-Subscriber",
  Handlers.utils.hasMatchingTag("Action", "Register-Whitelisted-Subscriber"),
  function(msg)
    Ownable.onlyOwner(msg) -- restrict access using the "@autonomousfinance/ownable" package
    Subscribable.handleRegisterWhitelistedSubscriber(msg) -- already exists in this package
  end
)
```

### Consider Access Control

Some API functions like `handleSetPaymentToken` and `handleRegisterWhitelistedSubscriber` should only be used in handlers that **restrict access**. In order to give your process "Ownable" capabilities, consider using [ownable](https://github.com/Autonomous-Finance/aos-packages/tree/main/packages/ownable) or [ownable-multi](https://github.com/Autonomous-Finance/aos-packages/tree/main/packages/ownable-multi).


## Conflict Considerations

⚠️ ❗️ If overriding functionality is not something you need, be mindful of potential conflicts in terms of the **`Handlers.list`**

Both your application code and other packages you install via APM, can potentially conflict with this package. Consider the following handlers as reserved by this package.

```lua

Handlers.list = {
  -- ...
  { 
    name = "subscribable.Register-Subscriber",
    -- ... 
  },
  { 
    name = "subscribable.Get-Subscriber",
    -- ... 
  },
  { 
    name = "subscribable.Receive-Payment",
    -- ... 
  },
  { 
    name = "subscribable.Get-Available-Topics",
    -- ... 
  },
  { 
    name = "subscribable.Subscribe-To-Topics",
    -- ... 
  },
  { 
    name = "subscribable.Unsubscribe-From-Topics",
    -- ... 
  }
  -- ...
}
```

## Persistence: Vanilla vs DB

The vanilla flavour uses simple lua tables to persist balances and subscriptions.

The DB flavour is highly scalable, suitable for processes with many subscribers. The downside there is some additional logical complexity and more verbose code, especially when extending the basic functionality.

We've built this non-sql flavour for the purpose of developer convenience, for cases where it would be scalable enough.



## TODO


- Get-Available-Topics (for autonomous agents)
  - info handler, rather?
  - topic names + metadata (json schema?)


- Topics: how are they built/defined? parameters

- topic parameter for lambda



- termination of a subscription

- info on conditions for registration

- topics, rather than events

- unify more



- remove subscriber
- data validation -> multiple topics passed in on registration / on subscription / on unsubscription

- Subscriptions and Balances - reconsider data structures (subscriptions and balances) for maximum efficiency
- (v2) balance subtraction "pay as you go", since we don't use cron and can't as easily predict outcomes