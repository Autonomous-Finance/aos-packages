if not Ownable then
  -- INITIAL DEPLOYMENT of example-process.lua

  local otherOwners = {
    'acc123-xyz-321-etc',
    -- ...
    --[[
      any wallet or process IDs, other than the spawner's ID
      The spawner's ID is implicitly one of the multiple owners
      ]]
  }
  -- Ownable = require "@autonomousfinance/ownable-multi" ({      -- requires installing with APM first
  Ownable = require "build.main" ({
    otherOwners = otherOwners
  })
else
  -- UPGRADE of example-process.lua

  -- reset the import in order to be able to re-import
  package.loaded['build.main'] = nil

  -- Ownable = require "@autonomousfinance/ownable-multi" ()      -- requires installing with APM first
  Ownable = require "build.main" ()
end

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
