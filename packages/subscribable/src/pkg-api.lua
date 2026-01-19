local json = require("json")
local bint = require(".bint")(256)

local function newmodule(pkg)
  --[[ TopicsAndChecks: Table
    Stores topic configurations and their associated check functions
    {
      [topicName]: {
        description: string,      -- Description of what the topic represents
        returns: string,          -- Description of what data is returned
        subscriptionBasis: string -- How the subscription works
        checkFn: function,        -- Function that determines if notification should be sent
        payloadFn: function       -- Function that generates the notification payload
      }
    }
  ]]
  pkg.TopicsAndChecks = pkg.TopicsAndChecks or {}

  -- Token used for subscription payments
  pkg.PAYMENT_TOKEN = '8p7ApPZxC_37M06QHVejCQrKsHbcJEerd3jWNkDUWPQ'
  pkg.PAYMENT_TOKEN_TICKER = 'BRKTST'


  -- REGISTRATION

  function pkg.sendReply(msg, data, tags)
    msg.reply({
      Action = msg.Tags.Action .. "-Response",
      Tags = tags,
      Data = json.encode(data)
    })
  end

  function pkg.sendConfirmation(target, action, tags)
    ao.send({
      Target = target,
      Action = action .. "-Confirmation",
      Tags = tags,
      Status = 'OK'
    })
  end

  --[[ registerSubscriber
    Registers a new subscriber process
    @param processId string: The process ID to register
    @param whitelisted boolean: If true, subscriber can receive notifications without payment
    @throws Error if process is already registered
  ]]
  function pkg.registerSubscriber(processId, whitelisted)
    local subscriberData = pkg._storage.getSubscriber(processId)

    if subscriberData then
      error('Process ' ..
        processId ..
        ' is already registered as a subscriber.')
    end

    pkg._storage.registerSubscriber(processId, whitelisted)

    pkg.sendConfirmation(
      processId,
      'Register-Subscriber',
      { Whitelisted = tostring(whitelisted) }
    )
  end

  --[[ handleRegisterSubscriber
    Handler function to be called by the user to subscribe with Payment
    @param msg table: Message sent the user
  ]]
  function pkg.handleRegisterSubscriber(msg)
    local processId = msg.From

    pkg.registerSubscriber(processId, false)
    pkg._subscribeToTopics(msg, processId)
  end

  --[[ handleRegisterWhitelistedSubscriber
  Handler function to be called by the Owner or the process itself to whiteliste a process Id
  @params msg table: Message sent by the Owner or the process itself
  ]]
  function pkg.handleRegisterWhitelistedSubscriber(msg)
    if msg.From ~= Owner and msg.From ~= ao.id then
      error('Only the owner or the process itself is allowed to register whitelisted subscribers')
    end

    local processId = msg.Tags['Subscriber-Process-Id']

    if not processId then
      error('Subscriber-Process-Id is required')
    end

    pkg.registerSubscriber(processId, true)
    pkg._subscribeToTopics(msg, processId)
  end

  --[[ handleGetSubscriber
  Handler function to be called by anyone to check the subscribtion details of a process Id
  @params msg table: Message sent by the user
  ]]
  function pkg.handleGetSubscriber(msg)
    local processId = msg.Tags['Subscriber-Process-Id']
    local replyData = pkg._storage.getSubscriber(processId)
    pkg.sendReply(msg, replyData)
  end

  --[[ updateBalance
    Updates a subscriber's balance
    @param processId string: The subscriber's process ID
    @param amount string: Amount to credit/debit
    @param isCredit boolean: True for credit, false for debit
    @throws Error if:
      - Subscriber not registered (for debits)
      - Insufficient balance (for debits)
  ]]
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

  --[[ handleReceivePayment
    Handler function for incoming subscription payments
    @param msg table: Message containing payment details
    Required Tags:
      - X-Subscriber-Process-Id: Target subscriber
      - Sender: Payment sender
      - Quantity: Payment amount
    @throws Error if payment token is incorrect or subscriber not specified
  ]]
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
        Action = "Pay-For-Subscription-Error",
        Status = "ERROR",
        Error = error
      })
      return
    end

    pkg.updateBalance(msg.Tags.Sender, msg.Tags.Quantity, true)

    pkg.sendConfirmation(msg.Sender, 'Pay-For-Subscription')

    print('Received subscription payment from ' ..
      msg.Tags.Sender .. ' of ' .. msg.Tags.Quantity .. ' ' .. msg.From .. " (" .. pkg.PAYMENT_TOKEN_TICKER .. ")")
  end

  --[[ handleSetPaymentToken
  Handler function to set the payment token
  @params msg table: Message sent by the user
  ]]
  function pkg.handleSetPaymentToken(msg)
    pkg.PAYMENT_TOKEN = msg.Tags.Token
  end

  -- TOPICS

  --[[ configTopicsAndChecks
    Sets the configuration for topics and their associated check functions
    @param cfg table: Configuration table containing topic definitions
      {
        [topicName]: {
          description: string,      -- Description of what the topic represents
          returns: string,          -- Description of what data is returned
          subscriptionBasis: string -- How the subscription works
          checkFn: function,        -- Function that determines if notification should be sent
          payloadFn: function       -- Function that generates the notification payload
        }
      }
  ]]
  function pkg.configTopicsAndChecks(cfg)
    pkg.TopicsAndChecks = cfg
  end

  --[[ getTopicsInfo
    Returns information about all configured topics without the internal functions
    @return table: Topic information excluding checkFn and payloadFn
      {
        [topicName]: {
          description: string,
          returns: string,
          subscriptionBasis: string
        }
      }
  ]]
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

  --[[ getInfo
    Returns general information about the subscription service
    @return table: Service information including payment details and topics
      {
        paymentTokenTicker: string,
        paymentToken: string,
        topics: table -- Result from getTopicsInfo()
      }
  ]]
  function pkg.getInfo()
    return {
      paymentTokenTicker = pkg.PAYMENT_TOKEN_TICKER,
      paymentToken = pkg.PAYMENT_TOKEN,
      topics = pkg.getTopicsInfo()
    }
  end

  -- SUBSCRIPTIONS

  --[[ _subscribeToTopics
    Internal function to handle topic subscription logic
    @param msg table: Message containing subscription details
    @param processId string: ID of the process to subscribe
    @throws Error if Topics tag is missing or process is not registered
  ]]
  function pkg._subscribeToTopics(msg, processId)
    assert(msg.Tags['Topics'], 'Topics is required')

    local topics = json.decode(msg.Tags['Topics'])

    pkg.onlyRegisteredSubscriber(processId)

    pkg._storage.subscribeToTopics(processId, topics)

    local subscriber = pkg._storage.getSubscriber(processId)

    pkg.sendConfirmation(
      processId,
      'Subscribe-To-Topics',
      { ["Updated-Topics"] = json.encode(subscriber.topics) }
    )
  end

  --[[ handleSubscribeToTopics
    Handler for subscription requests from subscribers
    @param msg table: Message from subscriber containing Topics in Tags
  ]]
  function pkg.handleSubscribeToTopics(msg)
    local processId = msg.From
    pkg._subscribeToTopics(msg, processId)
  end

  --[[ unsubscribeFromTopics
    Removes subscriber from specified topics
    @param processId string: ID of the process to unsubscribe
    @param topics table: List of topics to unsubscribe from
    @throws Error if process is not registered
  ]]
  function pkg.unsubscribeFromTopics(processId, topics)
    pkg.onlyRegisteredSubscriber(processId)

    pkg._storage.unsubscribeFromTopics(processId, topics)

    local subscriber = pkg._storage.getSubscriber(processId)

    pkg.sendConfirmation(
      processId,
      'Unsubscribe-From-Topics',
      { ["Updated-Topics"] = json.encode(subscriber.topics) }
    )
  end

  --[[ handleUnsubscribeFromTopics
    Handler for unsubscribe requests from subscribers
    @param msg table: Message from subscriber containing Topics in Tags
    @throws Error if Topics tag is missing
  ]]
  function pkg.handleUnsubscribeFromTopics(msg)
    assert(msg.Tags['Topics'], 'Topics is required')

    local processId = msg.From
    local topics = msg.Tags['Topics']

    pkg.unsubscribeFromTopics(processId, topics)
  end

  -- NOTIFICATIONS

  -- core dispatch functionality

  --[[ notifySubscribers
    Sends notification to all subscribers of a topic
    @param topic string: Topic to notify about
    @param payload table: Data to send to subscribers
  ]]
  function pkg.notifySubscribers(topic, payload)
    local targets = pkg._storage.getTargetsForTopic(topic)
    for _, target in ipairs(targets) do
      ao.send({
        Target = target,
        Action = 'Notify-On-Topic',
        Topic = topic,
        Data = json.encode(payload)
      })
    end
  end

  -- notify without check

  --[[ notifyTopics
    Sends notifications for multiple topics with their respective payloads
    @param topicsAndPayloads table: Map of topic to payload
    @param timestamp number: Timestamp to attach to notifications
  ]]
  function pkg.notifyTopics(topicsAndPayloads, timestamp)
    for topic, payload in pairs(topicsAndPayloads) do
      payload.timestamp = timestamp
      pkg.notifySubscribers(topic, payload)
    end
  end

  --[[ notifyTopic
    Convenience function to notify a single topic
    @param topic string: Topic to notify about
    @param payload table: Data to send to subscribers
    @param timestamp number: Timestamp to attach to notification
  ]]
  function pkg.notifyTopic(topic, payload, timestamp)
    return pkg.notifyTopics({
      [topic] = payload
    }, timestamp)
  end

  -- notify with configured checks

  --[[ checkNotifyTopics
    Checks conditions and notifies topics if conditions are met
    @param topics table: List of topics to check and potentially notify
    @param timestamp number: Timestamp to attach to notifications
  ]]
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

  --[[ checkNotifyTopic
    Convenience function to check and notify a single topic
    @param topic string: Topic to check and potentially notify
    @param timestamp number: Timestamp to attach to notification
  ]]
  function pkg.checkNotifyTopic(topic, timestamp)
    return pkg.checkNotifyTopics({ topic }, timestamp)
  end

  -- HELPERS

  --[[ onlyRegisteredSubscriber
    Helper function to verify if a process is registered as a subscriber
    @param processId string: Process ID to check
    @throws Error if process is not registered
  ]]
  pkg.onlyRegisteredSubscriber = function(processId)
    local subscriberData = pkg._storage.getSubscriber(processId)
    if not subscriberData then
      error('process ' .. processId .. ' is not registered as a subscriber')
    end
  end
end

return newmodule
