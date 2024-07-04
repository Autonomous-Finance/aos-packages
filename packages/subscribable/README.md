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

4. configure topics w/ corresponding event checks
5. notify subscribers to given topics
6. notify subscribers to given topics with event check

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

local sub = require("@autonomousfinance/subscribable")

--[[
  These capabilties include

  Handlers:
    - "registerSubscriber"
    - "receivePayment"

  API
    - configureTopics()
    - checkNotifyTopic()
    - checkNotifyTopics()
    - getRegisteredSubscriber()
    - ...
]]


sub.configTopics({
  {'even-counter', function() Counter % 2 == 0 end },
})

Counter = Counter = 0

-- Updates to Counter
Handlers.add(
  'increment',
  Handlers.utils.hasMatchingTag("Action", "Increment"),
  function()
    -- state change
    Counter = Counter + 1
    -- notifications
    sub.checkNotifyTopic('even-counter') -- will send out notifications if configured event check returns true
  end
)
```

## Overriding & Conflict Considerations

You can override handlers added by this package. Just use
```lua
Handlers.add(<package_handler_name>)
```
in your own code, after you've executed 
```lua
sub.load()
```

⚠️ ❗️ If overriding functionality is not something you need, be mindful of potential conflicts in terms of **global state** and the **`Handlers.list`**

Both your application code and other packages you install via APM, can potentially conflict with this package.

So, if you decide to use this package, consider the following

```lua
_G.Subscribable_Balances
_G.Subscribable_Subscriptions

Handlers.list = {
  -- ...

  -- the custom eval handlers MUST REMAIN AT THE TOP of the Handlers.list
  { 
    name = "subscribable.Register-Subscriber",
    -- ... 
  },
  { 
    name = "subscribable.Receive-Payment",
    -- ... 
  },
  { 
    name = "subscribable.Get-Subscriber",
    -- ... 
  }
  { 
    name = "subscribable.Get-Available-Topics",
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