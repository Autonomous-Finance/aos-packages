do
local _ENV = _ENV
package.preload[ "subscribable" ] = function( ... ) local arg = _G.arg;
package.loaded["pkg-api"] = nil
package.loaded["storage-vanilla"] = nil
package.loaded["storage-db"] = nil
do
local _ENV = _ENV
package.preload[ "pkg-api" ] = function( ... ) local arg = _G.arg;
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

    pkg._storage.unsubscribeFromTopics(processId, topics)

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
    if not pkg.Subscriptions[processId] then
      error('process ' .. processId .. ' is not registered as a subscriber')
    end

    if pkg.Subscriptions[processId].ownerId ~= ownerId then
      error('process ' .. processId .. ' is not registered as a subscriber with ownerId ' .. ownerId)
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

local function newmodule(pkg)
  local mod = {}
  pkg._storage = mod

  local sql = {}

  DB = DB or sqlite3.open_memory()

  sql.create_balances_table = [[
    CREATE TABLE IF NOT EXISTS balances (
        owner_id TEXT PRIMARY KEY,
        token_id TEXT NOT NULL,
        balance INT NOT NULL
    );
  ]]

  sql.create_subscriptions_table = [[
    CREATE TABLE IF NOT EXISTS subscriptions (
        process_id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        whitelisted INTEGER NOT NULL, -- 0 or 1 (false or true)
        topics TEXT  -- treated as JSON (an array of strings)
    );
  ]]

  local function createTableIfNotExists()
    DB:exec(sql.create_balances_table)
    print("Err: " .. DB:errmsg())

    DB:exec(sql.create_subscriptions_table)
    print("Err: " .. DB:errmsg())
  end

  createTableIfNotExists()

  -- REGISTRATION & BALANCES

  ---@param whitelisted boolean
  function mod.registerSubscriber(processId, ownerId, whitelisted)
    local stmt = DB:prepare [[
    INSERT INTO subscriptions (process_id, owner_id, whitelisted)
    VALUES (:process_id, :owner_id, :whitelisted)
  ]]
    if not stmt then
      error("Failed to prepare SQL statement for registering process: " .. DB:errmsg())
    end
    stmt:bind_names({
      process_id = processId,
      owner_id = ownerId,
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
    SELECT * FROM subscriptions WHERE process_id = :process_id
  ]]
    if not stmt then
      error("Failed to prepare SQL statement for checking subscriber: " .. DB:errmsg())
    end
    stmt:bind_names({ process_id = processId })
    return sql.queryOne(stmt)
  end

  function sql.updateBalance(ownerId, tokenId, amount, isCredit)
    local stmt = DB:prepare [[
    INSERT INTO balances (owner, token_id, balance)
    VALUES (:owner_id, :token_id, :amount)
    ON CONFLICT(owner) DO UPDATE SET
      balance = CASE
        WHEN :is_credit THEN balances.balance + :amount
        ELSE balances.balance - :amount
      END
    WHERE balances.token_id = :token_id;
  ]]
    if not stmt then
      error("Failed to prepare SQL statement for updating balance: " .. DB:errmsg())
    end
    stmt:bind_names({
      owner_id = ownerId,
      token_id = tokenId,
      amount = math.abs(amount), -- Ensure amount is positive
      is_credit = isCredit
    })
    local result, err = stmt:step()
    stmt:finalize()
    if err then
      error("Error updating balance: " .. DB:errmsg())
    end
  end

  function sql.getBalanceEntry(ownerId, tokenId)
    local stmt = DB:prepare [[
    SELECT * FROM balances WHERE owner_id = :owner_id AND token_id = :token_id
  ]]
    if not stmt then
      error("Failed to prepare SQL statement for getting balance entry: " .. DB:errmsg())
    end
    stmt:bind_names({ owner_id = ownerId, token_id = tokenId })
    return sql.queryOne(stmt)
  end

  -- SUBSCRIPTION

  function sql.subscribeToTopics(processId, topics)
    -- add the topics to the existing topics while avoiding duplicates
    local stmt = DB:prepare [[
    UPDATE subscriptions
    SET topics = (
        SELECT json_group_array(topic)
        FROM (
            SELECT json_each.value as topic
            FROM subscriptions, json_each(subscriptions.topics)
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
    UPDATE subscriptions
    SET topics = (
        SELECT json_group_array(topic)
        FROM (
            SELECT json_each.value as topic
            FROM subscriptions, json_each(subscriptions.topics)
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

  function sql.getTargetsForTopic(topic)
    local stmt = DB:prepare [[
    SELECT process_id
    FROM subscriptions as subs
    WHERE json_contains(topics, :topic) AND (subs.whitelisted = 1 OR EXISTS (
      SELECT 1
      FROM balances as b
      WHERE b.owner_id = subs.owner_id AND b.balance > 0
    ))
  ]]
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
end
end

local function newmodule(cfg)
  -- for bug-prevention, force the package user to be explicit
  assert(cfg.initial ~= nil, "cfg.initial is required: are you initializing or upgrading?")

  -- for bug-prevention, force the package user to be explicit on initial require
  assert(not cfg.initial or cfg.useDB ~= nil,
    "cfg.useDb is required: are you using the sqlite version (true) or the Lua-table based version (false)?")

  local pkg = cfg.existing or { useDB = cfg.useDB } -- useDB can only be set on initial; afterwards it remains the same

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
          and msg.From == pkg.PAYMENT_TOKEN
    end,
    pkg.handleReceivePayment
  )

  Handlers.add(
    "subscribable.Info",
    Handlers.utils.hasMatchingTag("Action", "Info"),
    pkg.handleGetInfo
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
end
end

--[[
  EXAMPLE PROCESS

  This Process tracks a Counter and a Greeting that can be publicly updated.

  It is also required to be subscribable.

  EVENTS that are interesting to subscribers
    - Counter is even
    - Greeting contains "gm" / "GM" / "gM" / "Gm"

  HANDLERS that may trigger the events
    - "increment" -> Counter is incremented
    - "setGreeting" -> Greeting is set
    - "setGreetingAsGmVariant" -> Greeting is set as a randomly generated variant of "GM"
    - "updateAll" -> Counter and Greeting are updated
]]

Counter = Counter or 0

Greeting = Greeting or "Hello"

if not Subscribable then
  -- INITIAL DEPLOYMENT of example-process.lua

  Subscribable = require 'subscribable' ({ -- when using the package with APM, require '@autonomousfinance/subscribable'
    initial = true,
    useDB = false
  })
else
  -- UPGRADE of example-process.lua

  -- We reuse all existing package state
  Subscribable = require 'subscribable' ({ -- when using the package with APM, require '@autonomousfinance/subscribable'
    initial = false,
    existing = Subscribable
  })
end

Handlers.add(
  'Increment',
  Handlers.utils.hasMatchingTag('Action', 'Increment'),
  function(msg)
    Counter = Counter + 1
    -- Check and send notifications if event occurs
    Subscribable.checkNotifyTopic('even-counter', msg.Timestamp)
  end
)

Handlers.add(
  'Set-Greeting',
  Handlers.utils.hasMatchingTag('Action', 'Set-Greeting'),
  function(msg)
    Greeting = msg.Tags.Greeting
    -- Check and send notifications if event occurs
    Subscribable.checkNotifyTopic('gm-greeting', msg.Timestamp)
  end
)

Handlers.add(
  'Set-Greeting-As-Gm-Variant',
  Handlers.utils.hasMatchingTag('Action', 'Set-Greeting-As-Gm-Variant'),
  function(msg)
    Greeting = 'GM-' .. tostring(math.random(1000, 9999))
    -- We know for sure that notifications should be sent --> this helps to avoid performing redundant computation
    Subscribable.notifyTopic('gm-greeting', msg.Timestamp)
  end
)

Handlers.add(
  'Update-All',
  Handlers.utils.hasMatchingTag('Action', 'Update-All'),
  function(msg)
    Greeting = msg.Tags.Greeting
    Counter = msg.Tags.Counter
    -- Check for multiple topics and send notifications if event occurs
    Subscribable.checkNotifyTopics(
      { 'even-counter', 'gm-greeting' },
      msg.Timestamp
    )
  end
)

-- CONFIGURE TOPICS AND CHECKS

-- We define CUSTOM TOPICS and corresponding CHECK FUNCTIONS
-- Check Functions use global state of this process (example.lua)
-- in order to determine if the event is occurring

local checkNotifyEvenCounter = function()
  return Counter % 2 == 0
end

local payloadForEvenCounter = function()
  return { counter = Counter }
end

local checkNotifyGreeting = function()
  return string.find(string.lower(Greeting), "gm")
end

local payloadForGreeting = function()
  return { greeting = Greeting }
end

Subscribable.configTopicsAndChecks({
  ['even-counter'] = {
    checkFn = checkNotifyEvenCounter,
    payloadFn = payloadForEvenCounter,
    description = 'Counter is even',
    returns = '{ "counter" : number }',
    subscriptionBasis = "Payment of 1 " .. Subscribable.PAYMENT_TOKEN_TICKER
  },
  ['gm-greeting'] = {
    checkFn = checkNotifyGreeting,
    payloadFn = payloadForGreeting,
    description = 'Greeting contains "gm" (any casing)',
    returns = '{ "greeting" : string }',
    subscriptionBasis = "Payment of 1 " .. Subscribable.PAYMENT_TOKEN_TICKER
  }
})
