local sqlite3 = require("lsqlite3")

local function newmodule(pkg)
  local mod = {}
  pkg._storage = mod

  local sql = {}

  DB = DB or sqlite3.open_memory()

  sql.create_balances_table = [[
    CREATE TABLE IF NOT EXISTS balances (
        owner_id TEXT PRIMARY KEY,
        token_id TEXT NOT NULL,
        balance INT NOT NULL
    );
  ]]

  sql.create_subscriptions_table = [[
    CREATE TABLE IF NOT EXISTS subscriptions (
        process_id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        whitelisted INTEGER NOT NULL, -- 0 or 1 (false or true)
        topics TEXT  -- treated as JSON (an array of strings)
    );
  ]]

  local function createTableIfNotExists()
    DB:exec(sql.create_balances_table)
    print("Err: " .. DB:errmsg())

    DB:exec(sql.create_subscriptions_table)
    print("Err: " .. DB:errmsg())
  end

  createTableIfNotExists()

  -- REGISTRATION & BALANCES

  ---@param whitelisted boolean
  function mod.registerSubscriber(processId, ownerId, whitelisted)
    local stmt = DB:prepare [[
    INSERT INTO subscriptions (process_id, owner_id, whitelisted)
    VALUES (:process_id, :owner_id, :whitelisted)
  ]]
    if not stmt then
      error("Failed to prepare SQL statement for registering process: " .. DB:errmsg())
    end
    stmt:bind_names({
      process_id = processId,
      owner_id = ownerId,
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
    SELECT * FROM subscriptions WHERE process_id = :process_id
  ]]
    if not stmt then
      error("Failed to prepare SQL statement for checking subscriber: " .. DB:errmsg())
    end
    stmt:bind_names({ process_id = processId })
    return sql.queryOne(stmt)
  end

  function sql.updateBalance(ownerId, tokenId, amount, isCredit)
    local stmt = DB:prepare [[
    INSERT INTO balances (owner, token_id, balance)
    VALUES (:owner_id, :token_id, :amount)
    ON CONFLICT(owner) DO UPDATE SET
      balance = CASE
        WHEN :is_credit THEN balances.balance + :amount
        ELSE balances.balance - :amount
      END
    WHERE balances.token_id = :token_id;
  ]]
    if not stmt then
      error("Failed to prepare SQL statement for updating balance: " .. DB:errmsg())
    end
    stmt:bind_names({
      owner_id = ownerId,
      token_id = tokenId,
      amount = math.abs(amount), -- Ensure amount is positive
      is_credit = isCredit
    })
    local result, err = stmt:step()
    stmt:finalize()
    if err then
      error("Error updating balance: " .. DB:errmsg())
    end
  end

  function sql.getBalanceEntry(ownerId, tokenId)
    local stmt = DB:prepare [[
    SELECT * FROM balances WHERE owner_id = :owner_id AND token_id = :token_id
  ]]
    if not stmt then
      error("Failed to prepare SQL statement for getting balance entry: " .. DB:errmsg())
    end
    stmt:bind_names({ owner_id = ownerId, token_id = tokenId })
    return sql.queryOne(stmt)
  end

  -- SUBSCRIPTION

  function sql.subscribeToTopics(processId, topics)
    -- add the topics to the existing topics while avoiding duplicates
    local stmt = DB:prepare [[
    UPDATE subscriptions
    SET topics = (
        SELECT json_group_array(topic)
        FROM (
            SELECT json_each.value as topic
            FROM subscriptions, json_each(subscriptions.topics)
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
    UPDATE subscriptions
    SET topics = (
        SELECT json_group_array(topic)
        FROM (
            SELECT json_each.value as topic
            FROM subscriptions, json_each(subscriptions.topics)
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

  function sql.getNotifiableSubscribersForTopic(topic)
    local stmt = DB:prepare [[
    SELECT process_id
    FROM subscriptions as subs
    WHERE json_contains(topics, :topic) AND (subs.whitelisted = 1 OR EXISTS (
      SELECT 1
      FROM balances as b
      WHERE b.owner_id = subs.owner_id AND b.balance > 0
    ))
  ]]
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
