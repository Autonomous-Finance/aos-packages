local json = require("json")
local bint = require(".bint")(256)

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

  function pkg.registerSubscriber(processId, whitelisted)
    local subscriberData = pkg._storage.getSubscriber(processId)

    if subscriberData then
      error('Process ' ..
        processId ..
        ' is already registered as a subscriber.')
    end

    pkg._storage.registerSubscriber(processId, whitelisted)

    ao.send({
      Target = processId,
      Action = 'Subscriber-Registration-Confirmation',
      Whitelisted = tostring(whitelisted),
      OK = 'true'
    })
  end

  function pkg.handleRegisterSubscriber(msg)
    local processId = msg.From

    pkg.registerSubscriber(processId, false)
    pkg.handleSubscribeToTopics(msg)
  end

  function pkg.handleRegisterWhitelistedSubscriber(msg)
    if msg.From ~= Owner then
      error('Only the owner is allowed to register whitelisted subscribers')
    end

    local processId = msg.Tags['Subscriber-Process-Id']

    if not processId then
      error('Subscriber-Process-Id is required')
    end

    pkg.registerSubscriber(processId, true)
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

  pkg.updateBalance = function(processId, amount, isCredit)
    local subscriber = pkg._storage.getSubscriber(processId)
    if not isCredit and not subscriber then
      error('Subscriber ' .. processId .. ' is not registered. Register first, then make a payment')
    end

    if not isCredit and bint(subscriber.balance) < bint(amount) then
      error('Insufficient balance for subscriber ' .. processId .. ' to be debited')
    end

    pkg._storage.updateBalance(processId, amount, isCredit)
  end

  function pkg.handleReceivePayment(msg)
    local processId = msg.Tags["X-Subscriber-Process-Id"]

    local error
    if not processId then
      error = "No subscriber specified"
    end

    if msg.From ~= pkg.PAYMENT_TOKEN then
      error = "Wrong token. Payment token is " .. (pkg.PAYMENT_TOKEN or "?")
    end

    if error then
      ao.send({
        Target = msg.From,
        Action = 'Transfer',
        Recipient = msg.Sender,
        Quantity = msg.Quantity,
        ["X-Action"] = "Subscription-Payment-Refund",
        ["X-Details"] = error
      })

      ao.send({
        Target = msg.Sender,
        ["Response-For"] = "Pay-For-Subscription",
        OK = "false",
        Data = error
      })
    end

    pkg.updateBalance(msg.Tags.Sender, msg.Tags.Quantity, true)

    ao.send({
      Target = msg.Sender,
      ["Response-For"] = "Pay-For-Subscription",
      OK = "true"
    })
    print('Received subscription payment from ' ..
      msg.Tags.Sender .. ' of ' .. msg.Tags.Quantity .. ' ' .. msg.From .. " (" .. pkg.PAYMENT_TOKEN_TICKER .. ")")
  end

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

  function pkg.getInfo()
    return {
      paymentTokenTicker = pkg.PAYMENT_TOKEN_TICKER,
      paymentToken = pkg.PAYMENT_TOKEN,
      topics = pkg.getTopicsInfo()
    }
  end

  -- SUBSCRIPTIONS

  function pkg.subscribeToTopics(processId, topics)
    pkg.onlyRegisteredSubscriber(processId)

    pkg._storage.subscribeToTopics(processId, topics)

    local subscriber = pkg._storage.getSubscriber(processId)

    ao.send({
      Target = processId,
      ['Response-For'] = 'Subscribe-To-Topics',
      OK = "true",
      ["Updated-Topics"] = subscriber.topics
    })
  end

  function pkg.handleSubscribeToTopics(msg)
    assert(msg.Tags['Topics'], 'Topics is required')

    local processId = msg.From
    local topics = json.decode(msg.Tags['Topics'])

    pkg.subscribeToTopics(processId, topics)
  end

  function pkg.unsubscribeFromTopics(processId, topics)
    pkg.onlyRegisteredSubscriber(processId)

    pkg._storage.unsubscribeFromTopics(processId, topics)

    local subscriber = pkg._storage.getSubscriber(processId)

    ao.send({
      Target = processId,
      ["Response-For"] = 'Unsubscribe-From-Topics',
      OK = "true",
      ["Updated-Topics"] = subscriber.topics
    })
  end

  function pkg.handleUnsubscribeFromTopics(msg)
    assert(msg.Tags['Topics'], 'Topics is required')

    local processId = msg.From
    local topics = msg.Tags['Topics']

    pkg.unsubscribeFromTopics(processId, topics)
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

  pkg.onlyRegisteredSubscriber = function(processId)
    local subscriberData = pkg._storage.getSubscriber(processId)
    if not subscriberData then
      error('process ' .. processId .. ' is not registered as a subscriber')
    end
  end
end

return newmodule
