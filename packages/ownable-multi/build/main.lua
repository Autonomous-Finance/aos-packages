package.loaded["utils"] = nil
package.loaded["subscriptions"] = nil
do
local _ENV = _ENV
package.preload[ "subscriptions" ] = function( ... ) local arg = _G.arg;
local bint = require ".bint" (256)
local json = require("json")
local utils = require "utils"

local function newmodule(pkg)
  --[[
    {
      topic: string = eventCheckFn: () => boolean
    }
  ]]
  pkg.TopicAndChecks = pkg.TopicAndChecks or {}


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
end
end

do
local _ENV = _ENV
package.preload[ "utils" ] = function( ... ) local arg = _G.arg;
local utils = { _version = "0.0.2" }

local function isArray(table)
  if type(table) == "table" then
    local maxIndex = 0
    for k, _ in pairs(table) do
      if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
        return false -- If there's a non-integer key, it's not an array
      end
      maxIndex = math.max(maxIndex, k)
    end
    -- If the highest numeric index is equal to the number of elements, it's an array
    return maxIndex == #table
  end
  return false
end

utils.keysOf = function(table)
  local keys = {}
  for k, _ in pairs(table) do
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
  assert(cfg.initial ~= nil, "cfg.initial is required: are you initializing or upgrading?") -- as a bug-safety measure, force the package user to be explicit

  local pkg = cfg.existing or {}

  pkg.version = '1.0.0'

  -- pkg acts like the package "global", bundling the state and API functions of the package

  require "subscriptions" (pkg)

  pkg.PAYMENT_TOKEN = 'Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc'

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
    "subscribable.Get-Available-Topics",
    Handlers.utils.hasMatchingTag("Action", "Get-Available-Topics"),
    pkg.handleGetAvailableTopics
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
