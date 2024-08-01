local sqlite3 = require("lsqlite3")
local bint = require(".bint")(256)

local function newmodule(pkg)
  local mod = {}
  pkg._storage = mod

  local sql = {}

  DB = DB or sqlite3.open_memory()

  sql.create_subscribers_table = [[
    CREATE TABLE IF NOT EXISTS subscribers (
        process_id TEXT PRIMARY KEY,
        topics TEXT,  -- treated as JSON (an array of strings)
        balance TEXT,
        whitelisted INTEGER NOT NULL, -- 0 or 1 (false or true)
    );
  ]]

  local function createTableIfNotExists()
    DB:exec(sql.create_subscribers_table)
    print("Err: " .. DB:errmsg())
  end

  createTableIfNotExists()

  -- REGISTRATION & BALANCES

  ---@param whitelisted boolean
  function mod.registerSubscriber(processId, whitelisted)
    local stmt = DB:prepare [[
    INSERT INTO subscribers (process_id, balance, whitelisted)
    VALUES (:process_id, :balance, :whitelisted)
  ]]
    if not stmt then
      error("Failed to prepare SQL statement for registering process: " .. DB:errmsg())
    end
    stmt:bind_names({
      process_id = processId,
      balance = "0",
      whitelisted = whitelisted and 1 or 0
    })
    local _, err = stmt:step()
    stmt:finalize()
    if err then
      error("Err: " .. DB:errmsg())
    end
  end

  function mod.getSubscriber(processId)
    local stmt = DB:prepare [[
    SELECT * FROM subscribers WHERE process_id = :process_id
  ]]
    if not stmt then
      error("Failed to prepare SQL statement for checking subscriber: " .. DB:errmsg())
    end
    stmt:bind_names({ process_id = processId })
    return sql.queryOne(stmt)
  end

  function sql.updateBalance(processId, amount, isCredit)
    local currentBalance = bint(sql.getBalance(processId))
    local diff = isCredit and bint(amount) or -bint(amount)
    local newBalance = tostring(currentBalance + diff)

    local stmt = DB:prepare [[
    UPDATE subscribers
    SET balance = :new_balance
    WHERE process_id = :process_id
  ]]
    if not stmt then
      error("Failed to prepare SQL statement for updating balance: " .. DB:errmsg())
    end
    stmt:bind_names({
      process_id = processId,
      new_balance = newBalance,
    })
    local result, err = stmt:step()
    stmt:finalize()
    if err then
      error("Error updating balance: " .. DB:errmsg())
    end
  end

  function sql.getBalance(processId)
    local stmt = DB:prepare [[
    SELECT * FROM subscribers WHERE process_id = :process_id
  ]]
    if not stmt then
      error("Failed to prepare SQL statement for getting balance entry: " .. DB:errmsg())
    end
    stmt:bind_names({ process_id = processId })
    local row = sql.queryOne(stmt)
    return row and row.balance or "0"
  end

  -- SUBSCRIPTION

  function sql.subscribeToTopics(processId, topics)
    -- add the topics to the existing topics while avoiding duplicates
    local stmt = DB:prepare [[
    UPDATE subscribers
    SET topics = (
        SELECT json_group_array(topic)
        FROM (
            SELECT json_each.value as topic
            FROM subscribers, json_each(subscribers.topics)
            WHERE process_id = :process_id

            UNION

            SELECT json_each.value as topic
            FROM json_each(:topics)
        )
    )
    WHERE process_id = :process_id;
  ]]
    if not stmt then
      error("Failed to prepare SQL statement for subscribing to topics: " .. DB:errmsg())
    end
    stmt:bind_names({
      process_id = processId,
      topic = topics
    })
    local _, err = stmt:step()
    stmt:finalize()
    if err then
      error("Err: " .. DB:errmsg())
    end
  end

  function sql.unsubscribeFromTopics(processId, topics)
    -- remove the topics from the existing topics
    local stmt = DB:prepare [[
    UPDATE subscribers
    SET topics = (
        SELECT json_group_array(topic)
        FROM (
            SELECT json_each.value as topic
            FROM subscribers, json_each(subscribers.topics)
            WHERE process_id = :process_id

            EXCEPT

            SELECT json_each.value as topic
            FROM json_each(:topics)
        )
    )
    WHERE process_id = :process_id;
  ]]
    if not stmt then
      error("Failed to prepare SQL statement for unsubscribing from topics: " .. DB:errmsg())
    end
    stmt:bind_names({
      process_id = processId,
      topic = topics
    })
    local _, err = stmt:step()
    stmt:finalize()
    if err then
      error("Err: " .. DB:errmsg())
    end
  end

  -- NOTIFICATIONS

  function sql.activationCondition()
    return [[
    (subs.whitelisted = 1 OR subs.balance <> "0")
  ]]
  end

  function sql.getTargetsForTopic(topic)
    local activationCondition = sql.activationCondition()
    local stmt = DB:prepare [[
    SELECT process_id
    FROM subscribers as subs
    WHERE json_contains(topics, :topic) AND ]] .. activationCondition

    if not stmt then
      error("Failed to prepare SQL statement for getting notifiable subscribers: " .. DB:errmsg())
    end
    stmt:bind_names({ topic = topic })
    return sql.queryMany(stmt)
  end

  -- UTILS

  function sql.queryMany(stmt)
    local rows = {}
    for row in stmt:nrows() do
      table.insert(rows, row)
    end
    stmt:reset()
    return rows
  end

  function sql.queryOne(stmt)
    return sql.queryMany(stmt)[1]
  end

  function sql.rawQuery(query)
    local stmt = DB:prepare(query)
    if not stmt then
      error("Err: " .. DB:errmsg())
    end
    return sql.queryMany(stmt)
  end

  return sql
end

return newmodule
