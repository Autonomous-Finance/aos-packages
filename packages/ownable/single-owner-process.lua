local mod = {}

mod.load = function()
  OWNERSHIP_RENOUNCER_PROCESS = 'XDY51mdAWjuEYEWaBNVR6p4mNGLHMDVvo5vPJOqEszg'
  Handlers.add(
    "transferOwnership",
    Handlers.utils.hasMatchingTag("Action", "TransferOwnership"),
    function(msg)
      mod.onlyOwner(msg)
      mod.transfer(msg)
    end
  )

  Handlers.add(
    "renounceOwnership",
    Handlers.utils.hasMatchingTag("Action", "RenounceOwnership"),
    function(msg)
      mod.onlyOwner(msg)
      Owner = OWNERSHIP_RENOUNCER_PROCESS
      msg.send({ Target = Owner, Action = 'MakeRenounce' })
    end
  )
end

-- INTERNAL FUNCTIONS

mod.onlyOwner = function(msg)
  assert(msg.From == Owner, "Only the owner is allowed")
end

mod.transfer = function(msg)
  local newOwner = msg.Tags.NewOwner
  assert(newOwner ~= nil and type(newOwner) == 'string', 'NewOwner is required!')
  Owner = newOwner
end

return mod
