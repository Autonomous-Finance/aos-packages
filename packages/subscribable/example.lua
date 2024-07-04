local internal = {}


--[[
  EXAMPLE BUSINESS LOGIC

  This Process tracks a Counter and a Greeting that can be publicly updated.

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

local sub = require 'build.main' -- LOAD SUBSCRIBABLE CAPABILITIES

-- Define CUSTOM TOPICS and corresponding CHECK FUNCTIONS
-- Check Functions use global state to determine if the event is occurring
sub.configTopics({
  ['even-counter'] = internal.checkNotifyCounter,
  ['gm-greeting'] = internal.checkNotifyGreeting
})

Handlers.add(
  'subscribable.Increment',
  Handlers.utils.hasMatchingTag('Action', 'Increment'),
  function(msg)
    Counter = Counter + 1
    -- Check and send notifications if event occurs
    sub.checkNotifyTopic('even-counter', msg.Timestamp)
  end
)

Handlers.add(
  'subscribable.Set-Greeting',
  Handlers.utils.hasMatchingTag('Action', 'Set-Greeting'),
  function(msg)
    Greeting = msg.Tags.Greeting
    -- Check and send notifications if event occurs
    sub.checkNotifyTopic('gm-greeting', msg.Timestamp)
  end
)

Handlers.add(
  'subscribable.Set-Greeting-As-Gm-Variant',
  Handlers.utils.hasMatchingTag('Action', 'Set-Greeting-As-Gm-Variant'),
  function(msg)
    Greeting = 'GM-' .. tostring(math.random(1000, 9999))
    -- We know for sure that notifications should be sent --> this helps to avoid performing redundant computation
    sub.notifyTopic('gm-greeting', msg.Timestamp)
  end
)

Handlers.add(
  'subscribable.Update-All',
  Handlers.utils.hasMatchingTag('Action', 'Update-All'),
  function(msg)
    Greeting = msg.Tags.Greeting
    Counter = msg.Tags.Counter
    -- Check for multiple topics and send notifications if event occurs
    sub.checkNotifyTopics(
      { 'even-counter', 'gm-greeting' },
      msg.Timestamp
    )
  end
)

-- INTERNAL

internal.checkNotifyCounter = function()
  if Counter % 2 == 0 then
    return true, {
      counter = Counter,
    }
  end
  return false
end

internal.checkNotifyGreeting = function()
  if string.find(string.lower(Greeting), "gm") then
    return true, {
      greeting = Greeting,
    }
  end
  return false
end
