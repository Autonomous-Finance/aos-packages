package.loaded["pkg-api"] = nil
package.loaded["storage-vanilla"] = nil
package.loaded["storage-db"] = nil
package.loaded["utils"] = nil
do
local _ENV = _ENV
package.preload[ "pkg-api" ] = function( ... ) local arg = _G.arg;
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


  pkg.PAYMENT_TOKEN = '8p7ApPZxC_37M06QHVejCQrKsHbcJEerd3jWNkDUWPQ'
  pkg.PAYMENT_TOKEN_TICKER = 'BRKTST'


  -- REGISTRATION

  function pkg.registerSubscriber(processId, ownerId, whitelisted)
    if pkg.Registrations[processId] then
      error('process ' ..
        processId ..
        ' already registered as a subscriber ' ..
        ' having ownerID = ' .. pkg.Subscriptions[processId].ownerID)
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

    if pkg.Subscriptions[processId].ownerID ~= ownerId then
      error('process ' .. processId .. ' is not registered as a subscriber with ownerID ' .. ownerId)
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
local utils = require "utils"

local function newmodule(pkg)
  local mod = {}
  pkg._storage = mod

  --[[
    {
      processId: ID = {
        ownerID: ID,
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

  function mod.getSubscriber(msg)
    return mod.Subscriptions[msg.Tags['Subscriber-Process-Id']]
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

    if mod.Subscriptions[processId].ownerID ~= ownerId then
      error('process ' .. processId .. ' is not registered as a subscriber with ownerID ' .. ownerId)
    end
  end
end

return newmodule
end
end

do
local _ENV = _ENV
package.preload[ "utils" ] = function( ... ) local arg = _G.arg;
local utils = { _version = "0.0.2" }

local function isArray(t)
  if type(t) == "table" then
    local maxIndex = 0
    for k, _ in pairs(t) do
      if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
        return false -- If there's a non-integer key, it's not an array
      end
      maxIndex = math.max(maxIndex, k)
    end
    -- If the highest numeric index is equal to the number of elements, it's an array
    return maxIndex == #t
  end
  return false
end

utils.keysOf = function(t)
  local keys = {}
  for k, _ in pairs(t) do
    table.insert(keys, k)
  end
  return keys
end

-- @param {function} fn
-- @param {number} arity
utils.curry = function(fn, arity)
  assert(type(fn) == "function", "function is required as first argument")
  arity = arity or debug.getinfo(fn, "u").nparams
  if arity < 2 then return fn end

  return function(...)
    local args = { ... }

    if #args >= arity then
      return fn(table.unpack(args))
    else
      return utils.curry(function(...)
        return fn(table.unpack(args), ...)
      end, arity - #args)
    end
  end
end

--- Concat two Array Tables.
-- @param {table<Array>} a
-- @param {table<Array>} b
utils.concat = utils.curry(function(a, b)
  assert(type(a) == "table", "first argument should be a table that is an array")
  assert(type(b) == "table", "second argument should be a table that is an array")
  assert(isArray(a), "first argument should be a table")
  assert(isArray(b), "second argument should be a table")

  local result = {}
  for i = 1, #a do
    result[#result + 1] = a[i]
  end
  for i = 1, #b do
    result[#result + 1] = b[i]
  end
  return result
end, 2)

--- reduce applies a function to a table
-- @param {function} fn
-- @param {any} initial
-- @param {table<Array>} t
utils.reduce = utils.curry(function(fn, initial, t)
  assert(type(fn) == "function", "first argument should be a function that accepts (result, value, key)")
  assert(type(t) == "table" and isArray(t), "third argument should be a table that is an array")
  local result = initial
  for k, v in pairs(t) do
    if result == nil then
      result = v
    else
      result = fn(result, v, k)
    end
  end
  return result
end, 3)

-- @param {function} fn
-- @param {table<Array>} data
utils.map = utils.curry(function(fn, data)
  assert(type(fn) == "function", "first argument should be a unary function")
  assert(type(data) == "table" and isArray(data), "second argument should be an Array")

  local function map(result, v, k)
    result[k] = fn(v, k)
    return result
  end

  return utils.reduce(map, {}, data)
end, 2)

-- @param {function} fn
-- @param {table<Array>} data
utils.filter = utils.curry(function(fn, data)
  assert(type(fn) == "function", "first argument should be a unary function")
  assert(type(data) == "table" and isArray(data), "second argument should be an Array")

  local function filter(result, v, _k)
    if fn(v) then
      table.insert(result, v)
    end
    return result
  end

  return utils.reduce(filter, {}, data)
end, 2)

-- @param {function} fn
-- @param {table<Array>} t
utils.find = utils.curry(function(fn, t)
  assert(type(fn) == "function", "first argument should be a unary function")
  assert(type(t) == "table", "second argument should be a table that is an array")
  for i, v in pairs(t) do
    if fn(v) then
      return v, i
    end
  end
  return nil, -1
end, 2)

-- @param {string} propName
-- @param {string} value
-- @param {table} object
utils.propEq = utils.curry(function(propName, value, object)
  assert(type(propName) == "string", "first argument should be a string")
  -- assert(type(value) == "string", "second argument should be a string")
  assert(type(object) == "table", "third argument should be a table<object>")

  return object[propName] == value
end, 3)

-- @param {table<Array>} data
utils.reverse = function(data)
  assert(type(data) == "table", "argument needs to be a table that is an array")
  return utils.reduce(
    function(result, v, i)
      result[#data - i + 1] = v
      return result
    end,
    {},
    data
  )
end

-- @param {function} ...
utils.compose = utils.curry(function(...)
  local mutations = utils.reverse({ ... })

  return function(v)
    local result = v
    for _, fn in pairs(mutations) do
      assert(type(fn) == "function", "each argument needs to be a function")
      result = fn(result)
    end
    return result
  end
end, 2)

-- @param {string} propName
-- @param {table} object
utils.prop = utils.curry(function(propName, object)
  return object[propName]
end, 2)

-- @param {any} val
-- @param {table<Array>} t
utils.includes = utils.curry(function(val, t)
  assert(type(t) == "table", "argument needs to be a table")
  return utils.find(function(v) return v == val end, t) ~= nil
end, 2)

-- @param {table} t
utils.keys = function(t)
  assert(type(t) == "table", "argument needs to be a table")
  local keys = {}
  for key in pairs(t) do
    table.insert(keys, key)
  end
  return keys
end

-- @param {table} t
utils.values = function(t)
  assert(type(t) == "table", "argument needs to be a table")
  local values = {}
  for _, value in pairs(t) do
    table.insert(values, value)
  end
  return values
end

return utils
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

  if cfg.initial then
    pkg.configTopics(cfg.topics)
  end

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
