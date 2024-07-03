-- version 1.1.1
local mod = {}

local internal = {}
local OWNERSHIP_RENOUNCER_PROCESS = '8kSVzbM6H25JeX3NuHp15qI_MAGq4vSka4Aer5ocYxE'

mod.load = function()
  Handlers.add(
    "ownable.Get-Owner",
    Handlers.utils.hasMatchingTag("Action", "Get-Owner"),
    function(msg)
      ao.send({ Target = msg.From, Data = Owner })
    end
  )

  Handlers.add(
    "ownable.Transfer-Ownership",
    Handlers.utils.hasMatchingTag("Action", "Transfer-Ownership"),
    function(msg)
      internal.onlyOwner(msg)
      internal.transfer(msg)
    end
  )

  Handlers.add(
    "ownable.Renounce-Ownership",
    Handlers.utils.hasMatchingTag("Action", "Renounce-Ownership"),
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
  local newOwner = msg.Tags['New-Owner']
  assert(newOwner ~= nil and type(newOwner) == 'string', 'New-Owner is required!')
  Owner = newOwner
  ao.send({ Target = ao.id, Event = "Transfer-Ownership", ["New-Owner"] = Owner })
end

return mod
