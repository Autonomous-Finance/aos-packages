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
    - "updateAll" -> Counter and Greeting are updated
]]

Counter = Counter or 0

Greeting = Greeting or "Hello"

Handlers.add(
  'increment',
  Handlers.utils.hasMatchingTag('Action', 'Increment'),
  function(msg)
    Counter = Counter + 1
    -- notifications are sent by the subscribable PACKAGE, based on a conditions defined by THIS process
    sub.checkNotifyTopic('even-counter', internal.checkNotifyCounter(msg))
  end
)

Handlers.add(
  'setGreeting',
  Handlers.utils.hasMatchingTag('Action', 'SetGreeting'),
  function(msg)
    Greeting = msg.Tags.Greeting
    -- notifications are sent by the subscribable PACKAGE, based on a conditions defined by THIS process
    sub.checkNotifyTopic('gm-greeting', internal.checkNotifyGreeting(msg))
  end
)

Handlers.add(
  'updateAll',
  Handlers.utils.hasMatchingTag('Action', 'UpdateAll'),
  function(msg)
    Greeting = msg.Tags.Greeting
    Counter = msg.Tags.Counter
    -- notifications are sent by the subscribable PACKAGE, based on a conditions defined by THIS process
    sub.checkNotifyTopics({
      ['even-counter'] = internal.checkNotifyCounter(msg),
      ['gm-greeting'] = internal.checkNotifyGreeting(msg)
    })
  end
)

-- INTERNAL

internal.checkNotifyCounter = function(msg)
  return function()
    if Counter % 2 == 0 then
      return true, {
        Counter = Counter,
        Timestamp = msg.Timestamp
      }
    end
    return false
  end
end

internal.checkNotifyGreeting = function(msg)
  return function()
    if string.find(string.lower(Greeting), "gm") then
      return true, {
        Greeting = Greeting,
        Timestamp = msg.Timestamp
      }
    end
    return false
  end
end
