local bint = require ".bint" (256)
local utils = require ".utils"

local function newmodule(pkg)
  local mod = {}
  pkg._storage = mod

  --[[
    {
      processId: ID = {
        topics: string[],
        balance: string,
        whitelisted: boolean -- if true, receives data without the need to pay
      }
    }
  ]]
  mod.Subscribers = mod.Subscribers or {}

  -- REGISTRATION & BALANCES

  function mod.registerSubscriber(processId, whitelisted)
    mod.Subscribers[processId] = mod.Subscribers[processId] or {
      balance = "0",
      topics = {},
      whitelisted = whitelisted,
    }
  end

  function mod.getSubscriber(processId)
    local data = mod.Subscribers[processId]
    return data and data.process_id or nil
  end

  function mod.updateBalance(processId, amount, isCredit)
    local current = bint(mod.Subscribers[processId].balance)
    local diff = isCredit and bint(amount) or -bint(amount)
    mod.Subscribers[processId].balance = tostring(current + diff)
  end

  -- SUBSCRIPTIONS

  function mod.subscribeToTopics(processId, topics)
    local existingTopics = mod.Subscribers[processId].topics
    for _, topic in ipairs(topics) do
      if not utils.includes(topic, existingTopics) then
        table.insert(existingTopics, topic)
      end
    end
  end

  function mod.unsubscribeFromTopics(processId, topics)
    local existingTopics = mod.Subscribers[processId].topics
    for _, topic in ipairs(topics) do
      existingTopics = utils.filter(
        function(t)
          return t ~= topic
        end,
        existingTopics
      )
    end
  end

  -- NOTIFICATIONS

  function mod.getTargetsForTopic(topic)
    local targets = {}
    for k, v in pairs(mod.Subscribers) do
      local mayReceiveNotification = mod.hasEnoughBalance(v.processId) or v.whitelisted
      if mod.isSubscribedTo(k, topic) and mayReceiveNotification then
        table.insert(targets, k)
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

    for _, subscribedTopic in ipairs(subscription.topics) do
      if subscribedTopic == topic then
        return true
      end
    end
    return false
  end
end

return newmodule
