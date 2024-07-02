local mod = {}

local subs = require "subscriptions"
local dispatcher = require "dispatcher"

local AOCRED = 'Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc'

mod.load = function()
  Handlers.add(
    "RegisterSubscriber",
    Handlers.utils.hasMatchingTag("Action", "Register-Subscriber"),
    subs.registerSubscriber
  )

  Handlers.add(
    "CreditNotice",
    function(msg)
      return Handlers.utils.hasMatchingTag("Action", "Credit-Notice")(msg)
          and msg.From == AOCRED
    end,
    subs.receivePayment
  )
end

mod.checkNotifyTopics = function(topicsAndChecks, timestamp)
  for topic, checkFn in pairs(topicsAndChecks) do
    local notify, payload = checkFn(topic)
    payload.timestamp = timestamp
    if notify then
      dispatcher.dispatch(topic, payload)
    end
  end
end

mod.checkNotifyTopic = function(topic, checkFn, timestamp)
  return mod.checkNotifyTopics({
    topic = topic,
    checkFn = checkFn
  }, timestamp)
end

return mod
