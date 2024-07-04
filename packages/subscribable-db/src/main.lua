local mod = {}

local sqlite3 = require("lsqlite3")
local sqlschema = require("sqlschema")

db = db or sqlite3.open_memory()


sqlschema.createTableIfNotExists(db)

Handlers.add(
  "subscribable-db.Register-Process",
  Handlers.utils.hasMatchingTag("Action", "Register-Process"),
  function(msg)
    local processId = msg.Tags['Subscriber-Process-Id']
    local ownerId = msg.Tags['Owner-Id']

    print('Registering process: ' .. processId .. ' with owner: ' .. ownerId)
    sqlschema.registerSubscriber(processId, ownerId)

    ao.send({
      Target = ao.id,
      Assignments = { ownerId, processId },
      Action = 'Registration-Confirmation',
      Process = processId,
      OK = 'true'
    })
  end
)

Handlers.add(
  "subscribable-db.Receive-Payment",
  function(msg)
    return Handlers.utils.hasMatchingTag("Action", "Credit-Notice")(msg)
        and msg.From == AOCRED
  end,
  function(msg)
    if msg.From == 'Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc' then
      sqlschema.updateBalance(msg.Tags.Sender, msg.From, tonumber(msg.Tags.Quantity), true)
    end
  end
)

return mod
