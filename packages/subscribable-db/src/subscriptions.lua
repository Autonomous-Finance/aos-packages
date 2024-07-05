local json = require("json")
local utils = require "utils"

local function newmodule(pkg)
  --[[
    {
      topic: string = eventCheckFn: () => boolean
    }
  ]]
  pkg.TopicAndChecks = pkg.TopicAndChecks or {}


  local sqlschema = require('sqlschema')

  -- REGISTRATION

  function pkg.registerSubscriber(processId, ownerId, whitelisted)
    local registeredSubscriber = sqlschema.getSubscriber(processId)
    if registeredSubscriber then
      error('process ' ..
        processId ..
        ' already registered as a subscriber ' ..
        ' having owner_id = ' .. registeredSubscriber.owner_id)
    end

    sqlschema.registerSubscriber(processId, ownerId, whitelisted)

    ao.send({
      Target = ao.id,
      Assignments = { ownerId, processId },
      Action = 'Subscriber-Registration-Confirmation',
      Whitelisted = tostring(whitelisted),
      Process = processId,
      OK = 'true'
    })
  end

  function pkg.handleRegisterSubscriber(msg)
    local processId = msg.Tags['Subscriber-Process-Id']
    local ownerId = msg.Tags['Owner-Id']
    pkg.registerSubscriber(processId, ownerId, false)
    pkg.subscribeToTopics(msg)
  end

  --- @dev only the main process owner should be able allowed here
  function pkg.handleRegisterWhitelistedSubscriber(msg)
    local processId = msg.Tags['Subscriber-Process-Id']
    local ownerId = msg.Tags['Owner-Id']
    pkg.registerSubscriber(processId, ownerId, true)
    pkg.subscribeToTopics(msg)
  end

  function pkg.handleGetSubscriber(msg)
    local processId = msg.Tags['Subscriber-Process-Id']
    ao.send({
      Target = msg.From,
      Data = json.encode(sqlschema.getSubscriber(processId))
    })
  end

  function pkg.handleReceivePayment(msg)
    pkg.updateBalance(msg.Tags.Sender, msg.From, msg.Tags.Quantity, true)
  end

  -- TOPICS

  function pkg.configTopicsAndChecks(cfg)
    pkg.TopicAndChecks = cfg
  end

  function pkg.getAvailableTopicsArray()
    return utils.keysOf(pkg.TopicAndChecks)
  end

  function pkg.handleGetAvailableTopics(msg)
    ao.send({
      Target = msg.From,
      Data = json.encode(utils.keysOf(pkg.TopicAndChecks))
    })
  end

  -- SUBSCRIPTIONS

  function pkg.subscribeToTopics(processId, ownerId, topics)
    pkg.onlyOwnedRegisteredSubscriber(processId, ownerId)

    sqlschema.subscribeToTopics(processId, topics)

    ao.send({
      Target = ao.id,
      Assignments = { ownerId, processId },
      Action = 'Subscribe-To-Topics',
      Process = processId,
      Topics = topics
    })
  end

  function pkg.handleSubscribeToTopics(msg)
    local processId = msg.Tags['Subscriber-Process-Id']
    local ownerId = msg.Tags['Owner-Id']
    local topics = msg.Tags['Topics']

    pkg.subscribeToTopics(processId, ownerId, topics)
  end

  function pkg.unsubscribeFromTopics(processId, ownerId, topics)
    pkg.onlyOwnedRegisteredSubscriber(processId, ownerId)

    sqlschema.unsubscribeFromTopics(processId, topics)

    ao.send({
      Target = ao.id,
      Assignments = { processId },
      Action = 'Unsubscribe-From-Topics',
      Process = processId,
      Topics = topics
    })
  end

  function pkg.handleUnsubscribeFromTopics(msg)
    local processId = msg.Tags['Subscriber-Process-Id']
    local ownerId = msg.Tags['Owner-Id']
    local topics = msg.Tags['Topics']

    pkg.unsubscribeFromTopics(processId, ownerId, topics)
  end

  -- NOTIFICATIONS

  -- core dispatch functionality

  function pkg.notifySubscribers(topic, payload)
    local targets = sqlschema.getNotifiableSubscribersForTopic(topic)

    if #targets > 0 then
      ao.send({
        ['Target'] = ao.id,
        ['Assignments'] = targets,
        ['Action'] = 'Notify-On-Topic',
        ['Topic'] = topic,
        ['Data'] = json.encode(payload)
      })
    end
  end

  -- notify without check

  function pkg.notifyTopics(topicsAndPayloads, timestamp)
    for topic, payload in pairs(topicsAndPayloads) do
      payload.timestamp = timestamp
      pkg.notifySubscribers(topic, payload)
    end
  end

  function pkg.notifyTopic(topic, payload, timestamp)
    return pkg.notifyTopics({
      [topic] = payload
    }, timestamp)
  end

  -- notify with configured checks

  function pkg.checkNotifyTopics(topics, timestamp)
    for _, topic in ipairs(topics) do
      local notify, payload = pkg.TopicAndChecks[topic]()
      if notify then
        payload.timestamp = timestamp
        pkg.notifySubscribers(topic, payload)
      end
    end
  end

  function pkg.checkNotifyTopic(topic, timestamp)
    return pkg.checkNotifyTopics({ topic }, timestamp)
  end

  -- HELPERS

  pkg.updateBalance = function(ownerId, tokenId, amount, isCredit)
    local balanceEntry = sqlschema.getBalanceEntry(ownerId, tokenId)
    if not isCredit and not balanceEntry then
      error('No balance entry exists for owner ' .. ownerId .. ' to be debited')
    end

    if not isCredit and balanceEntry.balance < amount then
      error('Insufficient balance for owner ' .. ownerId .. ' to be debited')
    end

    sqlschema.updateBalance(ownerId, tokenId, amount, isCredit)
  end

  pkg.onlyOwnedRegisteredSubscriber = function(processId, ownerId)
    local registeredSubscriber = sqlschema.getSubscriber()
    if not registeredSubscriber then
      error('process ' .. processId .. ' is not registered as a subscriber')
    end

    if registeredSubscriber.owner_id ~= ownerId then
      error('process ' .. processId .. ' is not registered as a subscriber with ownerID ' .. ownerId)
    end
  end
end

return newmodule
