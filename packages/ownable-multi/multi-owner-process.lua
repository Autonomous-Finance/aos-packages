local mod = {}


mod.load = function(initialOwners)
  OWNERSHIP_RENOUNCER_PROCESS = '1VUCSI8biIC1z47GGrasXIN0DScGJ3NCMe6arcA8phs'

  -- accounts that can act as owners
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
  Handlers.prepend(
    'customEval',
    function(msg)
      local isEval = Handlers.utils.hasMatchingTag("Action", "Eval")(msg)
      local isWhitelisted = Owners[msg.From]
      return isEval and isWhitelisted and "continue" or false
    end,
    function(msg)
      Owner = msg.From
    end
  )

  Handlers.add(
    "addOwner",
    Handlers.utils.hasMatchingTag("Action", "AddOwner"),
    function(msg)
      mod.onlyOwner(msg)
      mod.addOwner(msg)
    end
  )

  Handlers.add(
    "removeOwner",
    Handlers.utils.hasMatchingTag("Action", "RemoveOwner"),
    function(msg)
      mod.onlyOwner(msg)
      mod.removeOwner(msg)
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
      mod.onlyOwner(msg)
      Owners = nil
      Owner = OWNERSHIP_RENOUNCER_PROCESS
      msg.send({ Target = Owner, Action = 'MakeRenounce' })
    end
  )
end


-- INTERNAL FUNCTIONS

mod.onlyOwner = function(msg)
  if Owners == nil then
    assert(msg.From == Owner, "Only the owner is allowed")
  else
    assert(Owners[msg.From], "Only an owner is allowed")
  end
end

mod.addOwner = function(msg)
  local newOwner = msg.Tags.NewOwner
  assert(newOwner ~= nil and type(newOwner) == 'string', 'NewOwner is required!')
  Owners[newOwner] = true
end

mod.removeOwner = function(msg)
  local oldOwner = msg.Tags.OldOwner
  assert(oldOwner ~= nil and type(oldOwner) == 'string', 'OldOwner is required!')
  Owners[oldOwner] = nil
end

return mod
