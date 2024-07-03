## Features

- immediately notifies on qualifying event
- check for event explicity, or notify without a check
- supports topics

## TODO

- Subscriptions and Balances - data structures for efficiency
- (v2) balance subtraction "pay as you go", since we don't use cron and can't as easily predict outcomes



## Overriding & Conflict Considerations

You can override handlers added by this package. Just use
```lua
Handlers.add(<package_handler_name>)
```
in your own code, after you've executed 
```lua
ownable.load()
```

⚠️ ❗️ If overriding functionality is not something you need, be mindful of potential conflicts in terms of **global state** and the **`Handlers.list`**

Both your application code and other packages you install via APM, can potentially conflict with this package.

So, if you decide to use this package, consider the following

```lua
_G.Subscribable_Balances
_G.Subscribable_Subscriptions

Handlers.list = {
  -- ...

  -- the custom eval handlers MUST REMAIN AT THE TOP of the Handlers.list
  { 
    name = "subscribable.Register-Subscriber",
    -- ... 
  },
  { 
    name = "subscribable.Receive-Payment",
    -- ... 
  },
  { 
    name = "subscribable.Get-Topics",
    -- ... 
  }
  -- ...
}
```