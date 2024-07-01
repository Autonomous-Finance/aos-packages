local mod = {}

local json = require "json"

local internal = {}
mod.load = function(initialOwners)
  OWNERSHIP_RENOUNCER_PROCESS = '8kSVzbM6H25JeX3NuHp15qI_MAGq4vSka4Aer5ocYxE'

  -- accounts that can act as owners (key-value instead of array for simpler lookups)
  Owners = Owners or {
    [Owner] = true
  }

  if initialOwners then
    for _, owner in ipairs(initialOwners) do
      Owners[owner] = true
    end
  end

  --[[
    The process Owner changes on each Eval performed by one of the Owners.
    This approach allows for whitelisted wallets to interact with the process
    via the aos CLI as if they are regular owners.
    - Results from query Eval's like `aos> Owner` are displayed immediately in the CLI.
    - The process interface can be shut down and reopened by the whitelisted account
      regardless of who the last Eval caller (most recent process Owner) was
  ]]

  -- reassign owner if one of the whitelisted owners calls an Eval
  Handlers.prepend(
    'customEvalMatchPositive',
    function(msg)
      local isEval = Handlers.utils.hasMatchingTag("Action", "Eval")(msg)
      local isWhitelisted = Owners[msg.From]
      return isEval and isWhitelisted and "continue" or false
    end,
    function(msg)
      Owner = msg.From
    end
  )

  -- error if a non-whitelisted owner calls an Eval
  Handlers.prepend(
    'customEvalMatchNegative',
    function(msg)
      local isEval = Handlers.utils.hasMatchingTag("Action", "Eval")(msg)
      local isWhitelisted = Owners[msg.From]
      return isEval and not isWhitelisted
    end,
    function(msg)
      error("Only an owner is allowed")
    end
  )

  Handlers.add(
    "getOwners",
    Handlers.utils.hasMatchingTag("Action", "GetOwners"),
    function(msg)
      ao.send({ Target = msg.From, Data = json.encode(internal.getOwnersArray()) })
    end
  )

  Handlers.add(
    "addOwner",
    Handlers.utils.hasMatchingTag("Action", "AddOwner"),
    function(msg)
      internal.onlyOwner(msg)
      internal.addOwner(msg)
    end
  )

  Handlers.add(
    "removeOwner",
    Handlers.utils.hasMatchingTag("Action", "RemoveOwner"),
    function(msg)
      internal.onlyOwner(msg)
      internal.removeOwner(msg)
    end
  )

  --[[
    Renounce ownership altogether -> NONE of the accounts in Owners
    will be able to call owner-gated handlers anymore.
  ]]
  Handlers.add(
    "renounceOwnership",
    Handlers.utils.hasMatchingTag("Action", "RenounceOwnership"),
    function(msg)
      internal.onlyOwner(msg)
      Owners = nil
      Owner = OWNERSHIP_RENOUNCER_PROCESS
      msg.send({ Target = Owner, Action = 'MakeRenounce' })
    end
  )
end

-- INTERNAL FUNCTIONS

internal.onlyOwner = function(msg)
  if Owners == nil then
    assert(msg.From == Owner, "Only the owner is allowed")
  else
    assert(Owners[msg.From], "Only an owner is allowed")
  end
end

internal.addOwner = function(msg)
  local newOwner = msg.Tags.NewOwner
  assert(newOwner ~= nil and type(newOwner) == 'string', 'NewOwner is required!')
  Owners[newOwner] = true
  ao.send({ Target = ao.id, Event = "AddOwner", NewOwner = Owner, CurrentOwners = json.encode(internal.getOwnersArray()) })
end

internal.removeOwner = function(msg)
  local oldOwner = msg.Tags.OldOwner
  assert(oldOwner ~= nil and type(oldOwner) == 'string', 'OldOwner is required!')
  Owners[oldOwner] = nil
  ao.send({ Target = ao.id, Event = "AddOwner", OldOwner = Owner, CurrentOwners = json.encode(internal.getOwnersArray()) })
end

internal.getOwnersArray = function()
  local ownersArray = {}
  for owner, _ in pairs(Owners) do
    table.insert(ownersArray, owner)
  end
  return ownersArray
end

return mod
