# subscribable

## Subscription provider capabilities for an AO process

This package facilitates the development of AO processes that require the ability to register subscribers for specific topics and dispatch messages to them.
This solution is based on simple lua tables. 
If you require an sql-based solution, please refer to the [subscribable-db](https://github.com/Autonomous-Finance/aos-packages/tree/main/packages/subscribable-db/) package.

## Features

### Handlers

1. register subscriber
2. receive payment from subscriber (spam-protection / monetization) (only AOCRED)
3. get available topics
4. subscribe/unsubscribe a registered subscriber w/ specific topics

### API

5. configure topics w/ corresponding event checks
6. functions to implement the above Handlers or your own variations
7. ability to register a process as whitelisted
8. notify subscribers to given topics
9. notify subscribers to given topics with event check

## Installation

```lua
APM.install('@autonomousfinance/subscribable')
```

## Usage

1. Require the `subscribable` module in your Lua script
2. On this module, execute `.load()`
3. On this module, initially and whenever needed, execute `.configTopics()` to configure the supported topics and corresponding event checks
4. On this module, whenever topic-relevant state changes have occurred, execute `.notifyTopic()` or `.checkNotifyTopic()` to dispatch notifications to subscribers

```lua
-- process.lua

Subscribable = require("@autonomousfinance/subscribable")

--[[ 
  now you have 
  1. additional handlers added to Handlers.list
  2. the ability to use the ownable-multi API

    - configureTopics()
    - checkNotifyTopic()
    - checkNotifyTopics()
    - getRegisteredSubscriber()

    ...
]]

Counter = Counter = 0

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

### No global state pollution

Except for the `_G.Handlers.list`, the package affects nothing in the global space of your project. The state needed to manage multiple owners is **encapsulated in the package module**.
However, for upgradability we recommend assigning the required package to a global variable of your process (see below).

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

An example of this can be found in `example/example.lua`.

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

## Persistence

This package uses simple lua tables to persist balances and subscriptions.

A highly scalable alternative would be to use sqlite tables. The downside there is some additional logical complexity and more verbose code, especially when extending the basic functionality.

We've built this non-sql version for the purpose of developer convenience, for cases where it would be scalable enough.

## TODO

- data validation -> multiple topics passed in on registration / on subscription / on unsubscription

- Subscriptions and Balances - reconsider data structures (subscriptions and balances) for maximum efficiency
- (v2) balance subtraction "pay as you go", since we don't use cron and can't as easily predict outcomes