local bint = require ".bint" (256)
local utils = require ".utils"

local function newmodule(pkg)
  local mod = {}
  pkg._storage = mod

  --[[
    {
      processId: ID = {
        ownerId: ID,
        topics: string[],
        whitelisted: boolean -- if true, receives data without the need to pay
      }
    }
  ]]
  mod.Subscriptions = mod.Subscriptions or {}

  --[[
    {
      ownerId: ID = {
        tokenId: ID,
        balance: string
      }
    }
  ]]
  mod.Balances = mod.Balances or {}

  -- REGISTRATION & BALANCES

  function mod.registerSubscriber(processId, ownerId, whitelisted)
    mod.Subscriptions[processId] = mod.Subscriptions[processId] or {
      ownerId = ownerId,
      whitelisted = whitelisted,
      topics = {}
    }
  end

  function mod.getSubscriber(processId)
    return mod.Subscriptions[processId]
  end

  function mod.updateBalance(ownerId, tokenId, amount, isCredit)
    mod.Balances[ownerId] = mod.Balances[ownerId] or {
      tokenId = tokenId,
      amount = '0'
    }

    local current = bint(mod.Balances[ownerId].amount)
    local diff = isCredit and bint(amount) or -bint(amount)
    mod.Balances[ownerId].amount = tostring(current + diff)
  end

  -- SUBSCRIPTIONS

  function mod.subscribeToTopics(processId, topics)
    local existingTopics = mod.Subscriptions[processId].topics
    for _, topic in ipairs(topics) do
      if not utils.find(existingTopics, topic) then
        table.insert(existingTopics, topic)
      end
    end
  end

  function mod.unsubscribeFromTopics(processId, topics)
    local existingTopics = mod.Subscriptions[processId].topics
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
    for k, v in pairs(mod.Subscriptions) do
      local mayReceiveNotification = mod.hasBalance(v.ownerId) or v.whitelisted
      if mod.isSubscribedTo(k, topic) and mayReceiveNotification then
        table.insert(targets, k)
      end
    end
    return targets
  end

  -- HELPERS

  mod.hasBalance = function(ownerId)
    return mod.Balances[ownerId] and bint(mod.Balances[ownerId]) > 0
  end

  mod.onlyOwnedRegisteredSubscriber = function(processId, ownerId)
    if not mod.Subscriptions[processId] then
      error('process ' .. processId .. ' is not registered as a subscriber')
    end

    if mod.Subscriptions[processId].ownerId ~= ownerId then
      error('process ' .. processId .. ' is not registered as a subscriber with ownerId ' .. ownerId)
    end
  end
end

return newmodule
