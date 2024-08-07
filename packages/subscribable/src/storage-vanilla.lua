local bint = require ".bint" (256)
local json = require "json"
local utils = require ".utils"

local function newmodule(pkg)
  local mod = {
    Subscribers = pkg._storage and pkg._storage.Subscribers or {} -- we preserve state from previously used package
  }

  --[[
    mod.Subscribers :
    {
      processId: ID = {
        topics: string, -- JSON (string representation of a string[])
        balance: string,
        whitelisted: number -- 0 or 1 -- if 1, receives data without the need to pay
      }
    }
  ]]

  pkg._storage = mod

  -- REGISTRATION & BALANCES

  function mod.registerSubscriber(processId, whitelisted)
    mod.Subscribers[processId] = mod.Subscribers[processId] or {
      balance = "0",
      topics = json.encode({}),
      whitelisted = whitelisted and 1 or 0,
    }
  end

  function mod.getSubscriber(processId)
    local data = json.decode(json.encode(mod.Subscribers[processId]))
    if data then
      data.whitelisted = data.whitelisted == 1
      data.topics = json.decode(data.topics)
    end
    return data
  end

  function mod.updateBalance(processId, amount, isCredit)
    local current = bint(mod.Subscribers[processId].balance)
    local diff = isCredit and bint(amount) or -bint(amount)
    mod.Subscribers[processId].balance = tostring(current + diff)
  end

  -- SUBSCRIPTIONS

  function mod.subscribeToTopics(processId, topics)
    local existingTopics = json.decode(mod.Subscribers[processId].topics)

    for _, topic in ipairs(topics) do
      if not utils.includes(topic, existingTopics) then
        table.insert(existingTopics, topic)
      end
    end
    mod.Subscribers[processId].topics = json.encode(existingTopics)
  end

  function mod.unsubscribeFromTopics(processId, topics)
    local existingTopics = json.decode(mod.Subscribers[processId].topics)
    for _, topic in ipairs(topics) do
      existingTopics = utils.filter(
        function(t)
          return t ~= topic
        end,
        existingTopics
      )
    end
    mod.Subscribers[processId].topics = json.encode(existingTopics)
  end

  -- NOTIFICATIONS

  function mod.getTargetsForTopic(topic)
    local targets = {}
    for processId, v in pairs(mod.Subscribers) do
      local mayReceiveNotification = mod.hasEnoughBalance(processId) or v.whitelisted == 1
      if mod.isSubscribedTo(processId, topic) and mayReceiveNotification then
        table.insert(targets, processId)
      end
    end
    return targets
  end

  -- HELPERS

  mod.hasEnoughBalance = function(processId)
    return mod.Subscribers[processId] and bint(mod.Subscribers[processId].balance) > 0
  end

  mod.isSubscribedTo = function(processId, topic)
    local subscription = mod.Subscribers[processId]
    if not subscription then return false end

    local topics = json.decode(subscription.topics)
    for _, subscribedTopic in ipairs(topics) do
      if subscribedTopic == topic then
        return true
      end
    end
    return false
  end
end

return newmodule
