local subs = {}
local bint = require ".bint" (256)
local json = require("json")


local internal = {}

--[[
  {
    processId: ID = {
      ownerID: ID,
      topics: string[]
    }
  }
]]
Subscriptions = Subscriptions or {}


--[[
  {
    ownerId: ID = {
      tokenId: ID,
      balance: string
    }
  }
]]
Balances = Balances or {}

function subs.registerSubscriber(msg)
  local processId = msg.Tags['Subscriber-Process-Id']
  local ownerId = msg.Tags['Owner-Id']
  local topic = msg.Tags['Topic']

  print('Registering process: ' .. processId .. ' with owner: ' .. ownerId .. ' for topic ' .. topic)

  if internal.isSubscribedToTopic(processId, topic) then
    error('process ' ..
      processId ..
      ' already registered as a subscriber to topic ' ..
      topic .. ' having ownerID = ' .. Subscriptions[processId].ownerID)
  end

  Subscriptions[processId] = Subscriptions[processId] or {
    ownerId = ownerId,
    topics = {}
  }

  table.insert(Subscriptions[processId].topics, topic)

  ao.send({
    Target = ao.id,
    Assignments = { ownerId, processId },
    Action = 'Subscription-Confirmation',
    Process = processId,
    Topic = topic,
    OK = 'true'
  })
end

function subs.receivePayment(msg)
  internal.updateBalance(msg.Tags.Sender, msg.From, msg.Tags.Quantity, true)
end

function subs.notifySubscribers(topic, payload)
  local targets = {}
  for k, v in pairs(Subscriptions) do
    if internal.isSubscribedToTopic(k, topic) and internal.hasBalance(v.ownerID) then
      table.insert(targets, k)
    end
  end

  ao.send({
    ['Target'] = ao.id,
    ['Assignments'] = targets,
    ['Action'] = 'Notify-On-Topic',
    ['Topic'] = topic,
    ['Data'] = json.encode(payload)
  })
end

-- INTERNAL

internal.updateBalance = function(ownerId, tokenId, amount, isCredit)
  if not isCredit and not Balances[ownerId] then
    error('No balance entry exists for owner ' .. ownerId .. ' to be debited')
  end

  Balances[ownerId] = Balances[ownerId] or {
    tokenId = tokenId,
    amount = '0'
  }

  local current = bint(Balances[ownerId].amount)
  local diff = isCredit and bint(amount) or -bint(amount)
  Balances[ownerId].amount = tostring(current + diff)
end

internal.isSubscribedToTopic = function(processId, topic)
  if not Subscriptions[processId] then return false end
  for _, t in pairs(Subscriptions[processId].topics) do
    if t == topic then return true end
  end
  return false
end

internal.hasBalance = function(ownerId)
  return Balances[ownerId] and bint(Balances[ownerId]) > 0
end

return subs
