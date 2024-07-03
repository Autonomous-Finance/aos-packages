local mod = {}

local subs = require "subscriptions"
local dispatcher = require "dispatcher"

local AOCRED = 'Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc'

local topicsCfg = {}

mod.load = function()
  Handlers.add(
    "subscribable.Register-Subscriber",
    Handlers.utils.hasMatchingTag("Action", "Register-Subscriber"),
    subs.registerSubscriber
  )

  Handlers.add(
    "subscribable.Receive-Payment",
    function(msg)
      return Handlers.utils.hasMatchingTag("Action", "Credit-Notice")(msg)
          and msg.From == AOCRED
    end,
    subs.receivePayment
  )

  Handlers.add(
    "subscribable.Get-Topics",
    Handlers.utils.hasMatchingTag("Action", "Get-Topics"),
    function()
      return subs.getTopics()
    end
  )
end

mod.configTopics = function(cfg)
  topicsCfg = cfg
end

mod.getTopics = function()
  local topics = {}
  for topic, _ in pairs(topicsCfg) do
    table.insert(topics, topic)
  end
  return topics
end

-- dispatch without check

mod.notifyTopics = function(topicsAndPayloads, timestamp)
  for topic, payload in pairs(topicsAndPayloads) do
    payload.timestamp = timestamp
    dispatcher.dispatch(topic, payload)
  end
end

mod.notifyTopic = function(topic, payload, timestamp)
  return mod.notifyTopics({
    [topic] = payload
  }, timestamp)
end

-- dispatch with configured checks

mod.checkNotifyTopics = function(topics, timestamp)
  for _, topic in ipairs(topics) do
    local notify, payload = topicsCfg[topic].checkFn()
    payload.timestamp = timestamp
    if notify then
      dispatcher.dispatch(topic, payload)
    end
  end
end

mod.checkNotifyTopic = function(topic, timestamp)
  return mod.checkNotifyTopics({ topic }, timestamp)
end

return mod
