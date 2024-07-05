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
  Ownable = require "@autonomousfinance/ownable-multi" ({
    initial = true,
    otherOwners = otherOwners
  })
else
  -- UPGRADE of example-process.lua

  Ownable = require "@autonomousfinance/ownable-multi" ({
    initial = false,
    existing = Ownable
  })
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
