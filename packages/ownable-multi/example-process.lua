local initialOwners = {
  --[[
    wallet or process IDs, other than the spawner's ID,
    which is implicitly one of the multiple owners
  ]]
}
local ownable = require "@autonomousfinance/ownable-multi" (initialOwners)

Counter = Counter or 0

Handlers.add(
  "increment",
  Handlers.utils.hasMatchingTag("Action", "Increment"),
  function(msg)
    ownable.onlyOwner(msg)
    Counter = Counter + 1
  end
)
