local mod = {}

local json = require "json"

local internal = {}
local OWNERSHIP_RENOUNCER_PROCESS = '8kSVzbM6H25JeX3NuHp15qI_MAGq4vSka4Aer5ocYxE'

mod.load = function(initialOwners)
  -- accounts that can act as owners (key-value instead of array for simpler lookups)
  OwnableMulti_Owners = OwnableMulti_Owners or {
    [Owner] = true
  }

  if initialOwners then
    for _, owner in ipairs(initialOwners) do
      OwnableMulti_Owners[owner] = true
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
    'ownable-multi.customEvalMatchPositive',
    function(msg)
      local isEval = Handlers.utils.hasMatchingTag("Action", "Eval")(msg)
      local isWhitelisted = OwnableMulti_Owners[msg.From]
      return isEval and isWhitelisted and "continue" or false
    end,
    function(msg)
      Owner = msg.From
    end
  )

  -- error if a non-whitelisted owner calls an Eval
  Handlers.prepend(
    'ownable-multi.customEvalMatchNegative',
    function(msg)
      local isEval = Handlers.utils.hasMatchingTag("Action", "Eval")(msg)
      local isWhitelisted = OwnableMulti_Owners[msg.From]
      return isEval and not isWhitelisted
    end,
    function(msg)
      error("Only an owner is allowed")
    end
  )

  Handlers.add(
    "ownable-multi.getOwners",
    Handlers.utils.hasMatchingTag("Action", "GetOwners"),
    function(msg)
      ao.send({ Target = msg.From, Data = json.encode(internal.getOwnersArray()) })
    end
  )

  Handlers.add(
    "ownable-multi.addOwner",
    Handlers.utils.hasMatchingTag("Action", "AddOwner"),
    function(msg)
      internal.onlyOwner(msg)
      internal.addOwner(msg)
    end
  )

  Handlers.add(
    "ownable-multi.removeOwner",
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
    "ownable-multi.renounceOwnership",
    Handlers.utils.hasMatchingTag("Action", "RenounceOwnership"),
    function(msg)
      internal.onlyOwner(msg)
      OwnableMulti_Owners = nil
      Owner = OWNERSHIP_RENOUNCER_PROCESS
      msg.send({ Target = Owner, Action = 'MakeRenounce' })
    end
  )
end

-- INTERNAL FUNCTIONS

internal.onlyOwner = function(msg)
  if OwnableMulti_Owners == nil then
    assert(msg.From == Owner, "Only the owner is allowed")
  else
    assert(OwnableMulti_Owners[msg.From], "Only an owner is allowed")
  end
end

internal.addOwner = function(msg)
  local newOwner = msg.Tags.NewOwner
  assert(newOwner ~= nil and type(newOwner) == 'string', 'NewOwner is required!')
  OwnableMulti_Owners[newOwner] = true
  ao.send({ Target = ao.id, Event = "AddOwner", NewOwner = Owner, CurrentOwners = json.encode(internal.getOwnersArray()) })
end

internal.removeOwner = function(msg)
  local oldOwner = msg.Tags.OldOwner
  assert(oldOwner ~= nil and type(oldOwner) == 'string', 'OldOwner is required!')
  OwnableMulti_Owners[oldOwner] = nil
  ao.send({ Target = ao.id, Event = "AddOwner", OldOwner = Owner, CurrentOwners = json.encode(internal.getOwnersArray()) })
end

internal.getOwnersArray = function()
  local ownersArray = {}
  for owner, _ in pairs(OwnableMulti_Owners) do
    table.insert(ownersArray, owner)
  end
  return ownersArray
end

return mod
