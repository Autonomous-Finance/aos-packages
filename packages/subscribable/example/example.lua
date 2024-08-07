--[[
  EXAMPLE PROCESS

  This Process tracks a Counter and a Greeting that can be publicly updated.

  It is also required to be subscribable.

  EVENTS that are interesting to subscribers
    - Counter is even
    - Greeting contains "gm" / "GM" / "gM" / "Gm"

  HANDLERS that may trigger the events
    - "increment" -> Counter is incremented
    - "setGreeting" -> Greeting is set
    - "setGreetingAsGmVariant" -> Greeting is set as a randomly generated variant of "GM"
    - "updateAll" -> Counter and Greeting are updated
]]

Counter = Counter or 0

Greeting = Greeting or "Hello"

package.loaded['subscribable'] = nil
if not Subscribable then
  -- INITIAL DEPLOYMENT of example.lua

  Subscribable = require 'subscribable' ({ -- when using the package with APM, require '@autonomousfinance/subscribable'
    useDB = false
  })
else
  -- UPGRADE of example.lua

  -- We reuse all existing package state
  Subscribable = require 'subscribable' () -- when using the package with APM, require '@autonomousfinance/subscribable'
end

Handlers.add(
  'Increment',
  Handlers.utils.hasMatchingTag('Action', 'Increment'),
  function(msg)
    Counter = Counter + 1
    -- Check and send notifications if event occurs
    Subscribable.checkNotifyTopic('even-counter', msg.Timestamp)
  end
)

Handlers.add(
  'Set-Greeting',
  Handlers.utils.hasMatchingTag('Action', 'Set-Greeting'),
  function(msg)
    Greeting = msg.Tags.Greeting
    -- Check and send notifications if event occurs
    Subscribable.checkNotifyTopic('gm-greeting', msg.Timestamp)
  end
)

Handlers.add(
  'Set-Greeting-As-Gm-Variant',
  Handlers.utils.hasMatchingTag('Action', 'Set-Greeting-As-Gm-Variant'),
  function(msg)
    Greeting = 'GM-' .. tostring(math.random(1000, 9999))
    -- We know for sure that notifications should be sent --> this helps to avoid performing redundant computation
    Subscribable.notifyTopic('gm-greeting', { greeting = Greeting }, msg.Timestamp)
  end
)

Handlers.add(
  'Update-All',
  Handlers.utils.hasMatchingTag('Action', 'Update-All'),
  function(msg)
    Greeting = msg.Tags.Greeting
    Counter = msg.Tags.Counter
    -- Check for multiple topics and send notifications if event occurs
    Subscribable.checkNotifyTopics(
      { 'even-counter', 'gm-greeting' },
      msg.Timestamp
    )
  end
)

Handlers.add(
  'Whitelist-Subscriber',
  Handlers.utils.hasMatchingTag('Action', 'Whitelist-Subscriber'),
  function(msg)
    assert(msg.From == Owner or msg.From == ao.id, 'Only the owner can whitelist a subscriber')
    Subscribable._storage.Subscribers[msg.Tags['Process-ID']].whitelisted = 1
  end
)

-- CONFIGURE TOPICS AND CHECKS

-- We define CUSTOM TOPICS and corresponding CHECK FUNCTIONS
-- Check Functions use global state of this process (example.lua)
-- in order to determine if the event is occurring

local checkNotifyEvenCounter = function()
  return Counter % 2 == 0
end

local payloadForEvenCounter = function()
  return { counter = Counter }
end

local checkNotifyGreeting = function()
  return string.find(string.lower(Greeting), "gm")
end

local payloadForGreeting = function()
  return { greeting = Greeting }
end

Subscribable.configTopicsAndChecks({
  ['even-counter'] = {
    checkFn = checkNotifyEvenCounter,
    payloadFn = payloadForEvenCounter,
    description = 'Counter is even',
    returns = '{ "counter" : number }',
    subscriptionBasis = "Payment of 1 " .. Subscribable.PAYMENT_TOKEN_TICKER
  },
  ['gm-greeting'] = {
    checkFn = checkNotifyGreeting,
    payloadFn = payloadForGreeting,
    description = 'Greeting contains "gm" (any casing)',
    returns = '{ "greeting" : string }',
    subscriptionBasis = "Payment of 1 " .. Subscribable.PAYMENT_TOKEN_TICKER
  }
})
