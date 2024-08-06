Ownable = require "build.main"
-- Ownable = require "@autonomousfinance/ownable" -- when using the package with APM

Counter = Counter or 0

Handlers.add(
  "increment",
  Handlers.utils.hasMatchingTag("Action", "Increment"),
  function(msg)
    Ownable.onlyOwner(msg) -- must be sent from the owner wallet directly to this process
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
