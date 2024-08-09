local initialOwners = {
  --[[
    wallet IDs or process IDs, other than the spawner's ID
  ]]
  ['acc123-xyz-321-etc'] = true
}

-- Ownable = require "@autonomousfinance/ownable-multi" ({      -- requires installing with APM first
Ownable = require "build.main" ({
  initial = true,
  initialOwners = initialOwners
})

Counter = Counter or 0

Handlers.add(
  "increment",
  Handlers.utils.hasMatchingTag("Action", "Increment"),
  function(msg)
    Ownable.onlyOwner(msg)
    Counter = Counter + 1
  end
)

Handlers.add(
  "reset",
  Handlers.utils.hasMatchingTag("Action", "Reset"),
  function(msg)
    Ownable.onlyOwnerOrSelf(msg) -- must be sent either from the owner wallet or by opening this process in AOS
    Counter = 0
  end
)
