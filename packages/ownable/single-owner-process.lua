local mod = {}

local internal = {}

mod.load = function()
  OWNERSHIP_RENOUNCER_PROCESS = '8kSVzbM6H25JeX3NuHp15qI_MAGq4vSka4Aer5ocYxE'

  Handlers.add(
    "getOwner",
    Handlers.utils.hasMatchingTag("Action", "GetOwner"),
    function(msg)
      ao.send({ Target = msg.From, Data = Owner })
    end
  )

  Handlers.add(
    "transferOwnership",
    Handlers.utils.hasMatchingTag("Action", "TransferOwnership"),
    function(msg)
      internal.onlyOwner(msg)
      internal.transfer(msg)
    end
  )

  Handlers.add(
    "renounceOwnership",
    Handlers.utils.hasMatchingTag("Action", "RenounceOwnership"),
    function(msg)
      internal.onlyOwner(msg)
      Owner = OWNERSHIP_RENOUNCER_PROCESS
      ao.send({ Target = Owner, Action = 'MakeRenounce' })
    end
  )
end

-- INTERNAL FUNCTIONS


internal.onlyOwner = function(msg)
  assert(msg.From == Owner, "Only the owner is allowed")
end

internal.transfer = function(msg)
  local newOwner = msg.Tags.NewOwner
  assert(newOwner ~= nil and type(newOwner) == 'string', 'NewOwner is required!')
  Owner = newOwner
  ao.send({ Target = ao.id, Event = "TransferOwnership", NewOwner = Owner })
end

return mod
