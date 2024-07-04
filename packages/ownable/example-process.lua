local ownable = require("@autonomousfinance/ownable")

Counter = Counter or 0

Handlers.add(
  "increment",
  Handlers.utils.hasMatchingTag("Action", "Increment"),
  function(msg)
    ownable.onlyOwner(msg)
    Counter = Counter + 1
  end
)
