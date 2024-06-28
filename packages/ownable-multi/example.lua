local ownableMulti = require("@af/ownable-multi")

local initialOwners = {
  -- wallet or process IDs, other than the spawner's ID which is implicitly one of the multiple owners
}
ownableMulti.load(initialOwners)

Counter = Counter or 0

Handlers.add(
  "increment",
  Handlers.utils.hasMatchingTag("Action", "Increment"),
  function(msg)
    mod.onlyOwner(msg)
    Counter = Counter + 1
  end
)
