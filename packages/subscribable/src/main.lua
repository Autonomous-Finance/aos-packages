-- version 1.2.0
local pkg = {}

local AOCRED = 'Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc'

-- mod acts like the package "global", we assign to it the state and functions of the package
pkg = require "subscriptions" (pkg)

pkg.load = function()
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
          and msg.From == AOCRED
    end,
    pkg.handleRceivePayment
  )

  Handlers.add(
    "subscribable.Get-Available-Topics",
    Handlers.utils.hasMatchingTag("Action", "Get-Available-Topics"),
    pkg.getAvailableTopics
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
end

return pkg
