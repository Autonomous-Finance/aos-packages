local function newmodule(cfg)
  -- for bug-prevention, force the package user to be explicit
  assert(cfg.initial ~= nil, "cfg.initial is required: are you initializing or upgrading?")

  -- for bug-prevention, force the package user to be explicit on initial require
  assert(not cfg.initial or cfg.useDB ~= nil,
    "cfg.useDb is required: are you using the sqlite version (true) or the Lua-table based version (false)?")

  local pkg = cfg.existing or { useDB = cfg.useDB } -- useDB can only be set on initial; afterwards it remains the same

  pkg.version = '1.1.0'

  -- pkg acts like the package "global", bundling the state and API functions of the package

  if pkg.useDB then
    require "subscriptions-db" (pkg)
  else
    require "subscriptions" (pkg)
  end

  pkg.PAYMENT_TOKEN = '8p7ApPZxC_37M06QHVejCQrKsHbcJEerd3jWNkDUWPQ' -- BRKTST

  if cfg.initial then
    pkg.configTopics(cfg.topics)
  end

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
          and msg.From == pkg.PAYMENT_TOKEN
    end,
    pkg.handleReceivePayment
  )

  Handlers.add(
    "subscribable.Get-Available-Topics",
    Handlers.utils.hasMatchingTag("Action", "Get-Available-Topics"),
    pkg.handleGetAvailableTopics
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
