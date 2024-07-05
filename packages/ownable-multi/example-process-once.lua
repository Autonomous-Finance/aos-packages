local initialOwners = {
  --[[
    wallet IDs or process IDs, other than the spawner's ID
  ]]
  ['acc123-xyz-321-etc'] = true
}
Ownable = require "@autonomousfinance/ownable-multi" ({
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
