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
  -- INITIAL DEPLOYMENT of example-db.lua

  Subscribable = require 'subscribable' ({ -- when using the package with APM, require '@autonomousfinance/subscribable'
    initial = true,
    useDB = true
  })
else
  -- UPGRADE of example-db.lua

  -- We reuse all existing package state
  Subscribable = require 'subscribable' ({ -- when using the package with APM, require '@autonomousfinance/subscribable'
    initial = false,
    existing = Subscribable
  })
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
    Subscribable.notifyTopic('gm-greeting', msg.Timestamp)
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

-- CONFIGURE TOPICS AND CHECKS

-- We define CUSTOM TOPICS and corresponding CHECK FUNCTIONS
-- Check Functions use global state of this process (example.lua)
-- in order to determine if the event is occurring

local checkNotifyCounter = function()
  if Counter % 2 == 0 then
    return true, {
      counter = Counter,
    }
  end
  return false
end

local checkNotifyGreeting = function()
  if string.find(string.lower(Greeting), "gm") then
    return true, {
      greeting = Greeting,
    }
  end
  return false
end

Subscribable.configTopicsAndChecks({
  ['even-counter'] = checkNotifyCounter,
  ['gm-greeting'] = checkNotifyGreeting
})
