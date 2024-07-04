# subscribable-b

## Subscription provider capabilities for your AO process

This package facilitates the development of AO processes that require the ability to register subscribers for specific topics and dispatch messages to them.
This solution is based on sqlite. 
If you require a non-sql based solution, please refer to the [subscribable-db](https://github.com/Autonomous-Finance/aos-packages/tree/main/packages/subscribable/) package.

## Features

### Handlers

1. register subscriber
2. receive payment from subscriber (spam-protection / monetization) (only AOCRED)
3. get available topics

### Functions

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

sub.load()
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
_G.SubscribableDb_Balances
_G.SubscribableDb_Subscriptions

Handlers.list = {
  -- ...

  -- the custom eval handlers MUST REMAIN AT THE TOP of the Handlers.list
  { 
    name = "subscribable-db.Register-Subscriber",
    -- ... 
  },
  { 
    name = "subscribable-db.Receive-Payment",
    -- ... 
  },
  { 
    name = "subscribable-db.Get-Topics",
    -- ... 
  }
  -- ...
}
```
## TODO

- (v2) balance subtraction "pay as you go", since we don't use cron and can't as easily predict outcomes