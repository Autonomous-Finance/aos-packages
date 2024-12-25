# subscribable

## Subscription provider capabilities for an AO process

This package facilitates the development of AO processes that require the ability to register subscribers for events concerning specific topics. It effectively means that messages will be dispatched to subscribers whenever the topic-related events occur.

The package comes in two flavours:

1. The **vanilla** version is based on **simple Lua tables**.
2. The **DB** version is based on **sqlite3**, which is natively available on AO.

## Features

### Handlers

1. register subscriber
2. receive payment for (spam-protection / monetization) - a specific token needs to be configured
3. get available topics
4. subscribe/unsubscribe a registered subscriber w/ specific topics
5. get subscriber data

### API

1. configure topics w/ corresponding checks
2. functions to implement the above Handlers or your own variations
3. ability to register a process as whitelisted (gated to the process' `Owner`)
4. notify subscribers to given topics
5. notify subscribers to given topics with checks
6. configure the payment token (gated to the process' `Owner`)

## Usage

This package can be used via APM installation through `aos` or via a pre-build APM download into your project directory.

### APM download & require locally

Install `apm-tool` on your system. This cli tool allows you to download APM packages into your lua project.

```shell
npm i -g apm-tool
```

Downlad the package into your project as a single lua file:

```shell
cd your/project/directory
apm download @autonomousfinance/subscribable
cp apm_modules/@autonomousfinance/subscribable/source.lua ./subscribable.lua
```

Require the file locally from your main process lua file. 

```lua
Subscribable = require("subscribable") ({
  useDB = false -- using the vanilla flavour
})
```

The code in `example.lua` and `example-db.lua` demonstrates how to achieve this. 

📝 Keep in mind, with this approach you will eventually need to amalgamate your multiple lua files into a single lua file build that can be `.load`ed into your process via AOS. See `package/subscribable/build.sh` for an example of how to achieve this.

### APM install & require from APM

Connect with your process via `aos`. Perform the **steps 1 & 2 from your AOS client terminal**.

1. Install APM in your process

```lua
.load client-tool.lua
```

2. Install this package via APM

```lua
APM.install('@autonomousfinance/subscribable')
```

3. Require this package in your Lua script. The resulting table contains the package API. The `require` statement also adds package-specific handlers into the `_G.Handlers.list` of your process.

```lua
Subscribable = require "@autonomousfinance/subscribable" ({
  useDB = false -- using the vanilla flavour
})
```

### After requiring

After the package is required into your main process, you have

1. additional handlers added to Handlers.list
2. the ability to use the `subscribable` API

```lua
Subscribable.configTopicsAndChecks()

Subscribable.checkNotifyTopic()

Subscribable.checkNotifyTopics()

Subscribable.getRegisteredSubscriber()
```

Execute `.configTopicsAndChecks()` to configure the supported topics and corresponding checks. You can repeat this in the future as needed.

In your process handlers, wherever topic-relevant state changes have occurred, you can execute `.notifyTopic()` or `.checkNotifyTopic()` to dispatch notifications to subscribers.

Here is a simple example

```lua
Counter = Counter or 0

-- configure topic
Subscribable.configTopicsAndChecks({
  ['even-counter'] = {
    checkFn = function() return Counter % 2==0 end,
    payloadFn = function() return {counter = Counter} end,
    description = 'Counter is even'
  },
})

-- Updates to Counter
Handlers.add(
  'increment',
  Handlers.utils.hasMatchingTag("Action", "Increment"),
  function()
    -- state change
    Counter = Counter + 1
    -- notifications
    Subscribable.checkNotifyTopic('even-counter') -- sends out notifications based on check and payload from the topic event check function you configured
  end
)
```

### Explicit vs. Fully Automated

For the sake of computational efficiency, we opted **against fully automated subscriber notifications**.

It would have been possible to design the package such that *any state change* results in a check for topic events and then proceeds to notify all subscribers. 

In contrast, `subscribable` gives you a framework to easily **configure** your custom topic event checks, in that you define

1. what topics are supported
2. how the process state is checked to determine occurrence of a specific topic event

after which **you decide** where in your process handlers you want to perform checks for any given topic event. 

With the existing topic event checks being configured beforehand, your decision is coded declaratively - you can either 

1. `.checkNotifyTopic(<some_topic>)` - this checks for `<some_topic>` as configured by you. If positive, subscribers are then notified.
2. `.notifyTopic(<some_topic>)` - this notifies subscribers to `<some_topic>` without a check

With this approach you have more control over the occurrence of computation related to topic event checks and notification sending.

That being said, `subscribable` is designed to allow you to easily implement a **fully automated mechanism on top** of it, in your process which uses the package.


### Minimal global state pollution

The package affects nothing in the global space of your project, except for the `_G.Handlers.list` and `_G.DB` (if you opt for the *DB* flavour). The state needed for subscribable capabilities is **encapsulated in the package module**.

When opting for the *DB* flavour you'll probably be using sqlite in your own application code. For an efficient and yet convenient usage, this package makes `DB = sqlite3.open_memory()` a global singleton so that you wouldn't have to access it via the required package. Please keep in mind that this assignment only occurs once you require `subscribable` into your process.

For upgradability we recommend assigning the required package to a global variable of your process (see below).

## Upgrading your process

You may want your AO process to be upgradable, which includes the ability to upgrade this package as it is used by your process. 

In order to make this possible, this package gives you the option to `require` it as an upgrade.
```lua
Subscribable = require "@autonomousfinance/subscribable"()  -- or require "<your-local-path>/subscribable", as explained above
```
When doing that, the internal package state your process has been using so far (i.e. the subscribers and topics configuration), will be "adopted" by the new version of package. This only works **if you are using `Subscribable` as the name** for the global variable of the required package in your process.

Examples of this can be found in `example/example.lua` and `example/example-db.lua`.

❗️ The configuration for vanilla or db can only be used when you first require the package. Upgrades will not allow you to change flavour.

## Overriding Functionality

Similarly to extending a smart contract in Solidity, using this package allows builders to change the default functionality as needed.

### 1. You can override handlers added by this package

Either replace the handler entirely
```lua
Handlers.add(
  'subscribable.Register-Subscriber',
  -- your custom matcher,
  -- your custom handle function
)
```

or override handleFunctions
```lua
-- handle for "ownable-multi.Register-Subscriber"
function(msg)
  -- ADDITIONAL condition
  assert(isChristmasEve(msg.Timestamp))
  -- same as before
  Subscribable.handleRegisterSubscriber
end
```

### 2. You can override more specific API functions of this package

```lua
local originalRegisterSubscriber = Subscribable.registerSubscriber
Subscribable.registerSubscriber = function(processId, whitelisted)
  -- same as before
  originalRegisterSubscriber(processId, whitelisted)
  -- your ADDITIONAL logic
  ao.send({Target = AGGREGATOR_PROCESS, Action = "Subscriber-Registered", ["Process-ID"] = processId})
end
```

### 3. You can create new Handlers with available API functions of this package

```lua
Handlers.add(
  "Register-Whitelisted-Subscriber",
  Handlers.utils.hasMatchingTag("Action", "Register-Whitelisted-Subscriber"),
  Subscribable.handleRegisterWhitelistedSubscriber
)
```

### Consider Access Control

Some API functions like `handleSetPaymentToken` and `handleRegisterWhitelistedSubscriber` are gated - they **restrict access** to the current `Owner` of the process, or the process itself. In order to give your process "Ownable" capabilities (managing ownership), consider using [ownable](https://github.com/Autonomous-Finance/aos-packages/tree/main/packages/ownable) or [ownable-multi](https://github.com/Autonomous-Finance/aos-packages/tree/main/packages/ownable-multi).


## Subscription Model

1. Subscription clients subscribe and unsubscribe **themselves**
2. Subscriptions are not active by default. In the current implementation, their activation requires one of these conditions
   1. the client is registered as **whitelisted** (by you, the owner of the subscription server); this works well for partnerships
   2. the server receives is a **subscription payment** associated with the client; this can be refined to suit your business needs

### Whitelisting 
The current implementation includes a function `pkg.handleRegisterWhitelistedSubscriber(msg)`, but it is not exposed in a handler. You can do so if you need to

### Payments
Susbcriptions can be **paid for by anyone**, the reference being the **process id** of the subscriber (client).

The current implementation has a simple activation criteria: it only checks for the balance to be non-zero.

To customize this, you can override the relevant API function
- VANILLA VERSION: override `pkg.hasEnoughBalance(processId)` -> see `src/storage-vanilla.lua` for reference
- DB VERSION: override `pgk._store.getTargetsForTopic(topic)` -> see `src/storage-db.lua` for reference

You can find an example on how to override an API function in a section [above](#2-you-can-override-more-specific-api-functions-of-this-package).

### Example 

If you are using this package to become a **subscription server**, here is how another process would become your **client** (subscribe to you).

```lua
-- subscriber-process.lua

SUBSCRIPTION_SERVER = '...' -- your process id
SUBCSCRIPTION_PAYMENT_TOKEN  = '...' -- whatever you, as a subscription server, set as your pkg.PAYMENT_TOKEN
SUBSCRIPTION_PAYMENT_AMOUNT = '...' -- currently not checked by the package. there just has to be a positive balance in given token

-- subscription
ao.send({
  Target = SUBSCRIPTION_SERVER,
  Action = 'Register-Subscriber',
  Topics = json.encode(['latest-price'])
})
```

And here is how anyone could **activate the subscription** by paying for it. We demonstrate how the client itself would do it

```lua
ao.send({
  Target = SUBSCRIPTION_PAYMENT_TOKEN,
  Action = 'Transfer',
  Recipient = SUBSCRIPTION_SERVER,
  Quantity = SUBSCRIPTION_PAYMENT_AMOUNT,
  ["X-Action"] = "Pay-For-Subscription",
  ["X-Subscriber-Process-Id"] = ao.id -- the client process ID; this allows your process to associate the incoming payment with the particular subscriber ID
})
```

## Conflict Considerations

⚠️ ❗️ If overriding functionality is not something you need, be mindful of potential conflicts in terms of the **`Handlers.list`**

Both your application code and other packages you install via APM, can potentially conflict with this package. Consider the following handlers as reserved by this package.

```lua

Handlers.list = {
  -- ...
  { 
    name = "subscribable.Register-Subscriber",
    -- ... 
  },
  { 
    name = "subscribable.Get-Subscriber",
    -- ... 
  },
  { 
    name = "subscribable.Receive-Payment",
    -- ... 
  },
  { 
    name = "subscribable.Get-Available-Topics",
    -- ... 
  },
  { 
    name = "subscribable.Subscribe-To-Topics",
    -- ... 
  },
  { 
    name = "subscribable.Unsubscribe-From-Topics",
    -- ... 
  }
  -- ...
}
```

## Persistence: Vanilla vs DB

The vanilla flavour uses simple lua tables to persist balances and subscriptions.

The DB flavour is highly scalable, suitable for processes with many subscribers. The downside there is some additional logical complexity and more verbose code, especially when extending the basic functionality.

We've built this non-sql flavour for the purpose of developer convenience, for cases where it would be scalable enough.



## TODO

### docs
- Topics README section: how are they built/defined? parameters


### functionality 
- topics w/ parameter for lambda

- termination of a subscription

- remove subscriber


- data validation -> multiple topics passed in on registration / on subscription / on unsubscription

- (v2) balance subtraction "pay as you go", since we don't use cron and can't as easily predict outcomes
