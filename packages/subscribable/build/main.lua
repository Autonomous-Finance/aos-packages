package.loaded["pkg-api"] = nil
package.loaded["storage-vanilla"] = nil
package.loaded["storage-db"] = nil
do
local _ENV = _ENV
package.preload[ "pkg-api" ] = function( ... ) local arg = _G.arg;
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
    local targets = pkg._storage.activationCondition()

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
end
end

do
local _ENV = _ENV
package.preload[ "storage-db" ] = function( ... ) local arg = _G.arg;
local sqlite3 = require("lsqlite3")
local bint = require(".bint")(256)

local function newmodule(pkg)
  local mod = {}
  pkg._storage = mod

  local sql = {}

  DB = DB or sqlite3.open_memory()

  sql.create_subscribers_table = [[
    CREATE TABLE IF NOT EXISTS subscribers (
        process_id TEXT PRIMARY KEY,
        topics TEXT,  -- treated as JSON (an array of strings)
        balance TEXT,
        whitelisted INTEGER NOT NULL, -- 0 or 1 (false or true)
    );
  ]]

  local function createTableIfNotExists()
    DB:exec(sql.create_subscribers_table)
    print("Err: " .. DB:errmsg())
  end

  createTableIfNotExists()

  -- REGISTRATION & BALANCES

  ---@param whitelisted boolean
  function mod.registerSubscriber(processId, whitelisted)
    local stmt = DB:prepare [[
    INSERT INTO subscribers (process_id, balance, whitelisted)
    VALUES (:process_id, :balance, :whitelisted)
  ]]
    if not stmt then
      error("Failed to prepare SQL statement for registering process: " .. DB:errmsg())
    end
    stmt:bind_names({
      process_id = processId,
      balance = "0",
      whitelisted = whitelisted and 1 or 0
    })
    local _, err = stmt:step()
    stmt:finalize()
    if err then
      error("Err: " .. DB:errmsg())
    end
  end

  function mod.getSubscriber(processId)
    local stmt = DB:prepare [[
    SELECT * FROM subscribers WHERE process_id = :process_id
  ]]
    if not stmt then
      error("Failed to prepare SQL statement for checking subscriber: " .. DB:errmsg())
    end
    stmt:bind_names({ process_id = processId })
    return sql.queryOne(stmt)
  end

  function sql.updateBalance(processId, amount, isCredit)
    local currentBalance = bint(sql.getBalance(processId))
    local diff = isCredit and bint(amount) or -bint(amount)
    local newBalance = tostring(currentBalance + diff)

    local stmt = DB:prepare [[
    UPDATE subscribers
    SET balance = :new_balance
    WHERE process_id = :process_id
  ]]
    if not stmt then
      error("Failed to prepare SQL statement for updating balance: " .. DB:errmsg())
    end
    stmt:bind_names({
      process_id = processId,
      new_balance = newBalance,
    })
    local result, err = stmt:step()
    stmt:finalize()
    if err then
      error("Error updating balance: " .. DB:errmsg())
    end
  end

  function sql.getBalance(processId)
    local stmt = DB:prepare [[
    SELECT * FROM subscribers WHERE process_id = :process_id
  ]]
    if not stmt then
      error("Failed to prepare SQL statement for getting balance entry: " .. DB:errmsg())
    end
    stmt:bind_names({ process_id = processId })
    return sql.queryOne(stmt).balance
  end

  -- SUBSCRIPTION

  function sql.subscribeToTopics(processId, topics)
    -- add the topics to the existing topics while avoiding duplicates
    local stmt = DB:prepare [[
    UPDATE subscribers
    SET topics = (
        SELECT json_group_array(topic)
        FROM (
            SELECT json_each.value as topic
            FROM subscribers, json_each(subscribers.topics)
            WHERE process_id = :process_id

            UNION

            SELECT json_each.value as topic
            FROM json_each(:topics)
        )
    )
    WHERE process_id = :process_id;
  ]]
    if not stmt then
      error("Failed to prepare SQL statement for subscribing to topics: " .. DB:errmsg())
    end
    stmt:bind_names({
      process_id = processId,
      topic = topics
    })
    local _, err = stmt:step()
    stmt:finalize()
    if err then
      error("Err: " .. DB:errmsg())
    end
  end

  function sql.unsubscribeFromTopics(processId, topics)
    -- remove the topics from the existing topics
    local stmt = DB:prepare [[
    UPDATE subscribers
    SET topics = (
        SELECT json_group_array(topic)
        FROM (
            SELECT json_each.value as topic
            FROM subscribers, json_each(subscribers.topics)
            WHERE process_id = :process_id

            EXCEPT

            SELECT json_each.value as topic
            FROM json_each(:topics)
        )
    )
    WHERE process_id = :process_id;
  ]]
    if not stmt then
      error("Failed to prepare SQL statement for unsubscribing from topics: " .. DB:errmsg())
    end
    stmt:bind_names({
      process_id = processId,
      topic = topics
    })
    local _, err = stmt:step()
    stmt:finalize()
    if err then
      error("Err: " .. DB:errmsg())
    end
  end

  -- NOTIFICATIONS

  function sql.activationCondition()
    return [[
    (subs.whitelisted = 1 OR subs.balance <> "0")
  ]]
  end

  function sql.getTargetsForTopic(topic)
    local activationCondition = sql.activationCondition()
    local stmt = DB:prepare [[
    SELECT process_id
    FROM subscribers as subs
    WHERE json_contains(topics, :topic) AND ]] .. activationCondition

    if not stmt then
      error("Failed to prepare SQL statement for getting notifiable subscribers: " .. DB:errmsg())
    end
    stmt:bind_names({ topic = topic })
    return sql.queryMany(stmt)
  end

  -- UTILS

  function sql.queryMany(stmt)
    local rows = {}
    for row in stmt:nrows() do
      table.insert(rows, row)
    end
    stmt:reset()
    return rows
  end

  function sql.queryOne(stmt)
    return sql.queryMany(stmt)[1]
  end

  function sql.rawQuery(query)
    local stmt = DB:prepare(query)
    if not stmt then
      error("Err: " .. DB:errmsg())
    end
    return sql.queryMany(stmt)
  end

  return sql
end

return newmodule
end
end

do
local _ENV = _ENV
package.preload[ "storage-vanilla" ] = function( ... ) local arg = _G.arg;
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
    data.process_id = processId
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
end
end

local function newmodule(cfg)
  local isInitial = Subscribable == nil

  -- for bug-prevention, force the package user to be explicit on initial require
  assert(not isInitial or cfg.useDB ~= nil,
    "cfg.useDb is required: are you using the sqlite version (true) or the Lua-table based version (false)?")


  local pkg = Subscribable or
      { useDB = cfg.useDB } -- useDB can only be set on initialization; afterwards it remains the same

  pkg.version = '1.1.0'

  -- pkg acts like the package "global", bundling the state and API functions of the package

  if pkg.useDB then
    require "storage-db" (pkg)
  else
    require "storage-vanilla" (pkg)
  end

  require "pkg-api" (pkg)

  Handlers.add(
    "subscribable.Register-Subscriber",
    Handlers.utils.hasMatchingTag("Action", "Register-Subscriber"),
    pkg.handleRegisterSubscriber
  )

  Handlers.add(
    'subscribable.Get-Subscriber',
    Handlers.utils.hasMatchingTag('Action', 'Get-Subscriber'),
    pkg.handleGetSubscriber
  )

  Handlers.add(
    "subscribable.Receive-Payment",
    function(msg)
      return Handlers.utils.hasMatchingTag("Action", "Credit-Notice")(msg)
          and Handlers.utils.hasMatchingTag("X-Action", "Pay-For-Subscription")(msg)
    end,
    pkg.handleReceivePayment
  )

  Handlers.add(
    'subscribable.Subscribe-To-Topics',
    Handlers.utils.hasMatchingTag('Action', 'Subscribe-To-Topics'),
    pkg.handleSubscribeToTopics
  )

  Handlers.add(
    'subscribable.Unsubscribe-From-Topics',
    Handlers.utils.hasMatchingTag('Action', 'Unsubscribe-From-Topics'),
    pkg.handleUnsubscribeFromTopics
  )

  return pkg
end
return newmodule
