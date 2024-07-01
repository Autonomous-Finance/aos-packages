local ownable = require("@autonomousfinance/ownable")

ownable.load() -- handlers and global variables are added

Counter = Counter or 0

Handlers.add(
  "increment",
  Handlers.utils.hasMatchingTag("Action", "Increment"),
  function(msg)
    mod.onlyOwner(msg)
    Counter = Counter + 1
  end
)
