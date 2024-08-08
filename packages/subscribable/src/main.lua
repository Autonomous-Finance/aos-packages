local function newmodule(cfg)
  local isInitial = Subscribable == nil

  -- for bug-prevention, force the package user to be explicit on initial require
  assert(not isInitial or cfg.useDB ~= nil,
    "cfg.useDb is required: are you using the sqlite version (true) or the Lua-table based version (false)?")


  local pkg = Subscribable or
      { useDB = cfg.useDB } -- useDB can only be set on initialization; afterwards it remains the same

  pkg.version = '1.3.3'

  -- pkg acts like the package "global", bundling the state and API functions of the package

  if pkg.useDB then
    require "storage-db" (pkg)
  else
    require "storage-vanilla" (pkg)
  end

  require "pkg-api" (pkg)

  Handlers.add(
    "subscribable.Register-Subscriber",
    Handlers.utils.hasMatchingTag("Action", "Register-Subscriber"),
    pkg.handleRegisterSubscriber
  )

  Handlers.add(
    'subscribable.Get-Subscriber',
    Handlers.utils.hasMatchingTag('Action', 'Get-Subscriber'),
    pkg.handleGetSubscriber
  )

  Handlers.add(
    "subscribable.Receive-Payment",
    function(msg)
      return Handlers.utils.hasMatchingTag("Action", "Credit-Notice")(msg)
          and Handlers.utils.hasMatchingTag("X-Action", "Pay-For-Subscription")(msg)
    end,
    pkg.handleReceivePayment
  )

  Handlers.add(
    'subscribable.Subscribe-To-Topics',
    Handlers.utils.hasMatchingTag('Action', 'Subscribe-To-Topics'),
    pkg.handleSubscribeToTopics
  )

  Handlers.add(
    'subscribable.Unsubscribe-From-Topics',
    Handlers.utils.hasMatchingTag('Action', 'Unsubscribe-From-Topics'),
    pkg.handleUnsubscribeFromTopics
  )

  return pkg
end
return newmodule
