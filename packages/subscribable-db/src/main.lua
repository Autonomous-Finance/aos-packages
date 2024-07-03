local mod = {}

local sqlschema = require("sqlschema")

db = db or sqlite3.open_memory()


sqlschema.createTableIfNotExists(db)

Handlers.add(
  "RegisterProcess",
  Handlers.utils.hasMatchingTag("Action", "Register-Process"),
  function(msg)
    local processId = msg.Tags['Subscriber-Process-Id']
    local ownerId = msg.Tags['Owner-Id']

    print('Registering process: ' .. processId .. ' with owner: ' .. ownerId)
    sqlschema.registerProcess(processId, ownerId)

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
  "CreditNotice",
  Handlers.utils.hasMatchingTag("Action", "Credit-Notice"),
  function(msg)
    if msg.From == 'Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc' then
      sqlschema.updateBalance(msg.Tags.Sender, msg.From, tonumber(msg.Tags.Quantity), true)
    end
  end
)

return mod
