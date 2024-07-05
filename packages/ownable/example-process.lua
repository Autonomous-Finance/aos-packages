Ownable = require "build.main"
-- Ownable = require "@autonomousfinance/ownable" -- when actually using the package with APM

Counter = Counter or 0

Handlers.add(
  "increment",
  Handlers.utils.hasMatchingTag("Action", "Increment"),
  function(msg)
    Ownable.onlyOwner(msg)
    Counter = Counter + 1
  end
)
