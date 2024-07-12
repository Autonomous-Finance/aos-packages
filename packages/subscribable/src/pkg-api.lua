local json = require("json")

local function newmodule(pkg)
  --[[
    {
      topic: string = eventCheckFn: () => boolean
    }
  ]]
  pkg.TopicsAndChecks = pkg.TopicsAndChecks or {}


  pkg.PAYMENT_TOKEN = '8p7ApPZxC_37M06QHVejCQrKsHbcJEerd3jWNkDUWPQ'
  pkg.PAYMENT_TOKEN_TICKER = 'BRKTST'


  -- REGISTRATION

  function pkg.registerSubscriber(processId, ownerId, whitelisted)
    local subscriberData = pkg._storage.getSubscriber(processId)

    if subscriberData then
      error('process ' ..
        processId ..
        ' already registered as a subscriber ' ..
        ' having ownerId = ' .. subscriberData.ownerId)
    end

    pkg._storage.registerSubscriber(processId, ownerId, whitelisted)

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
    pkg.handleSubscribeToTopics(msg)
  end

  --- @dev only the main process owner should be able allowed here
  function pkg.handleRegisterWhitelistedSubscriber(msg)
    local processId = msg.Tags['Subscriber-Process-Id']
    local ownerId = msg.Tags['Owner-Id']
    pkg.registerSubscriber(processId, ownerId, true)
    pkg.handleSubscribeToTopics(msg)
  end

  function pkg.handleGetSubscriber(msg)
    local processId = msg.Tags['Subscriber-Process-Id']
    local subscriberData = pkg._storage.getSubscriber(processId)
    ao.send({
      Target = msg.From,
      Data = json.encode(subscriberData)
    })
  end

  pkg.updateBalance = function(ownerId, tokenId, amount, isCredit)
    local balanceEntry = pkg._storage.getBalanceEntry(ownerId, tokenId)
    if not isCredit and not balanceEntry then
      error('No balance entry exists for owner ' .. ownerId .. ' to be debited')
    end

    if not isCredit and balanceEntry.balance < amount then
      error('Insufficient balance for owner ' .. ownerId .. ' to be debited')
    end

    pkg._storage.updateBalance(ownerId, tokenId, amount, isCredit)
  end

  function pkg.handleReceivePayment(msg)
    pkg.updateBalance(msg.Tags.Sender, msg.From, msg.Tags.Quantity, true)
  end

  --- @dev only the main process owner should be able allowed here
  function pkg.handleSetPaymentToken(msg)
    pkg.PAYMENT_TOKEN = msg.Tags.Token
  end

  -- TOPICS

  function pkg.configTopicsAndChecks(cfg)
    pkg.TopicsAndChecks = cfg
  end

  function pkg.getTopicsInfo()
    local topicsInfo = {}
    for topic, _ in pairs(pkg.TopicsAndChecks) do
      local topicInfo = pkg.TopicsAndChecks[topic]
      topicsInfo[topic] = {
        description = topicInfo.description,
        returns = topicInfo.returns,
        subscriptionBasis = topicInfo.subscriptionBasis
      }
    end

    return topicsInfo
  end

  function pkg.handleGetInfo(msg)
    local info = {
      paymentToken = pkg.PAYMENT_TOKEN,
      topics = pkg.getTopicsInfo()
    }
    ao.send({
      Target = msg.From,
      Data = json.encode(info)
    })
  end

  -- SUBSCRIPTIONS

  function pkg.subscribeToTopics(processId, ownerId, topics)
    pkg.onlyOwnedRegisteredSubscriber(processId, ownerId)

    pkg._storage.subscribeToTopics(processId, topics)

    ao.send({
      Target = ao.id,
      Assignments = { ownerId, processId },
      Action = 'Subscribe-To-Topics',
      Process = processId,
      Topics = json.encode(topics)
    })
  end

  function pkg.handleSubscribeToTopics(msg)
    local processId = msg.Tags['Subscriber-Process-Id']
    local ownerId = msg.Tags['Owner-Id']
    local topics = json.decode(msg.Tags['Topics'])

    pkg.subscribeToTopics(processId, ownerId, topics)
  end

  function pkg.unsubscribeFromTopics(processId, ownerId, topics)
    pkg.onlyOwnedRegisteredSubscriber(processId, ownerId)

    pkg._storage.unsubscribeFromTopics(processId, topics)

    ao.send({
      Target = ao.id,
      Assignments = { processId },
      Action = 'Unsubscribe-From-Topics',
      Process = processId,
      Topics = json.encode(topics)
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
    local targets = pkg._storage.getTargetsForTopic(topic)

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
      local shouldNotify = pkg.TopicsAndChecks[topic].checkFn()
      if shouldNotify then
        local payload = pkg.TopicsAndChecks[topic].payloadFn()
        payload.timestamp = timestamp
        pkg.notifySubscribers(topic, payload)
      end
    end
  end

  function pkg.checkNotifyTopic(topic, timestamp)
    return pkg.checkNotifyTopics({ topic }, timestamp)
  end

  -- HELPERS

  pkg.onlyOwnedRegisteredSubscriber = function(processId, ownerId)
    local subscriberData = pkg._storage.getSubscriber(processId)
    if not subscriberData then
      error('process ' .. processId .. ' is not registered as a subscriber')
    end

    if subscriberData.ownerId ~= ownerId then
      error('process ' .. processId .. ' is not registered as a subscriber with ownerId ' .. ownerId)
    end
  end
end

return newmodule
