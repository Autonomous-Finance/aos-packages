local sub = require 'src.main'
local internal = {}

sub.load() -- LOAD SUBSCRIBABLE CAPABILITIES
--[[
  These capabilties include

  Handlers:
    - "registerSubscriber"
    - "receivePayment"

  Sending notifications:
    - checkNotifyTopic()
    - checkNotifyTopics()
]]



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

-- Define CUSTOM TOPICS and corresponding CHECK FUNCTION
-- Check Functions use global state to determine if the event is occurring
sub.configTopics({
  ['even-counter'] = internal.checkNotifyCounter,
  ['gm-greeting'] = internal.checkNotifyGreeting
})

Handlers.add(
  'increment',
  Handlers.utils.hasMatchingTag('Action', 'Increment'),
  function(msg)
    Counter = Counter + 1
    -- Check and send notifications if event occurs
    sub.checkNotifyTopic('even-counter', msg.Timestamp)
  end
)

Handlers.add(
  'setGreeting',
  Handlers.utils.hasMatchingTag('Action', 'SetGreeting'),
  function(msg)
    Greeting = msg.Tags.Greeting
    -- Check and send notifications if event occurs
    sub.checkNotifyTopic('gm-greeting', msg.Timestamp)
  end
)

Handlers.add(
  'setGreetingAsGmVariant',
  Handlers.utils.hasMatchingTag('Action', 'SetGreetingAsGmVariant'),
  function(msg)
    Greeting = 'GM-' .. tostring(math.random(1000, 9999))
    -- We know for sure that notifications should be sent --> this helps to avoid performing redundant computation
    sub.notifyTopic('gm-greeting', msg.Timestamp)
  end
)

Handlers.add(
  'updateAll',
  Handlers.utils.hasMatchingTag('Action', 'UpdateAll'),
  function(msg)
    Greeting = msg.Tags.Greeting
    Counter = msg.Tags.Counter
    -- Check for multiple topics and send notifications if event occurs
    sub.checkNotifyTopics({
      ['even-counter'] = internal.checkNotifyCounter,
      ['gm-greeting'] = internal.checkNotifyGreeting
    }, msg.Timestamp)
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
