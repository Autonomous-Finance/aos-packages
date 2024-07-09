local bint = require ".bint" (256)
local json = require("json")
local utils = require "utils"

local function newmodule(pkg)
  --[[
    {
      topic: string = eventCheckFn: () => boolean
    }
  ]]
  pkg.TopicsAndChecks = pkg.TopicsAndChecks or {}


  --[[
    {
      processId: ID = {
        ownerID: ID,
        topics: string[],
        whitelisted: boolean -- if true, receives data without the need to pay
      }
    }
  ]]
  pkg.Subscriptions = pkg.Subscriptions or {}

  --[[
    {
      ownerId: ID = {
        tokenId: ID,
        balance: string
      }
    }
  ]]
  pkg.Balances = pkg.Balances or {}

  -- REGISTRATION

  function pkg.registerSubscriber(processId, ownerId, whitelisted)
    if pkg.Registrations[processId] then
      error('process ' ..
        processId ..
        ' already registered as a subscriber ' ..
        ' having ownerID = ' .. pkg.Subscriptions[processId].ownerID)
    end

    pkg.Subscriptions[processId] = pkg.Subscriptions[processId] or {
      ownerId = ownerId,
      whitelisted = whitelisted,
      topics = {}
    }

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
      Data = json.encode(pkg.Subscriptions[processId])
    })
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
        type = topicInfo.params and 'dynamic' or 'static',
        params = topicInfo.params,
      }
    end

    return topicsInfo
  end

  function pkg.handleGetInfo(msg)
    local info = {
      paymentToken = pkg.PAYMENT_TOKEN,
      topics = utils.keysOf(pkg.TopicsAndChecks)
    }
    ao.send({
      Target = msg.From,
      Data = json.encode(info)
    })
  end

  -- SUBSCRIPTIONS

  function pkg.subscribeToTopics(processId, ownerId, topics)
    pkg.onlyOwnedRegisteredSubscriber(processId, ownerId)

    local existingTopics = pkg.Subscriptions[processId].topics
    for _, topic in ipairs(topics) do
      if not utils.find(existingTopics, topic) then
        table.insert(existingTopics, topic)
      end
    end

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

    local existingTopics = pkg.Subscriptions[processId].topics
    for _, topic in ipairs(topics) do
      existingTopics = utils.filter(
        function(t)
          return t ~= topic
        end,
        existingTopics
      )
    end

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
    local targets = {}
    for k, v in pairs(pkg.Subscriptions) do
      local mayReceiveNotification = pkg.hasBalance(v.ownerId) or v.whitelisted
      if pkg.isSubscribedTo(k, topic) and mayReceiveNotification then
        table.insert(targets, k)
      end
    end

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

  local function callCheckFn(fn, paramNames)
    if not paramNames then return fn() end

    local params = utils.map(
      function(paramName) return _G[paramName] end,
      paramNames
    )
    ---@diagnostic disable-next-line: param-type-mismatch
    return fn(table.unpack(params))
  end

  function pkg.checkNotifyTopics(topics, timestamp)
    for _, topic in ipairs(topics) do
      local checkFn = pkg.TopicsAndChecks[topic].check
      local checkFnParams = pkg.TopicsAndChecks[topic].params

      local notify, payload = callCheckFn(checkFn, checkFnParams)
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
    if not isCredit and not pkg.Balances[ownerId] then
      error('No balance entry exists for owner ' .. ownerId .. ' to be debited')
    end

    pkg.Balances[ownerId] = pkg.Balances[ownerId] or {
      tokenId = tokenId,
      amount = '0'
    }

    local current = bint(pkg.Balances[ownerId].amount)
    local diff = isCredit and bint(amount) or -bint(amount)
    pkg.Balances[ownerId].amount = tostring(current + diff)
  end

  pkg.hasBalance = function(ownerId)
    return pkg.Balances[ownerId] and bint(pkg.Balances[ownerId]) > 0
  end

  pkg.onlyOwnedRegisteredSubscriber = function(processId, ownerId)
    if not pkg.Subscriptions[processId] then
      error('process ' .. processId .. ' is not registered as a subscriber')
    end

    if pkg.Subscriptions[processId].ownerID ~= ownerId then
      error('process ' .. processId .. ' is not registered as a subscriber with ownerID ' .. ownerId)
    end
  end
end

return newmodule
