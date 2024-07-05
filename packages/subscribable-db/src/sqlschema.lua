local sqlschema = {}

sqlschema.create_balances_table = [[
CREATE TABLE IF NOT EXISTS balances (
    owner_id TEXT PRIMARY KEY,
    token_id TEXT NOT NULL,
    balance INT NOT NULL
);
]]

sqlschema.create_subscriptions_table = [[
CREATE TABLE IF NOT EXISTS subscriptions (
    process_id TEXT PRIMARY KEY,
    owner_id TEXT NOT NULL,
    whitelisted INTEGER NOT NULL, -- 0 or 1 (false or true)
    topics TEXT  -- treated as JSON (an array of strings)
);
]]

function sqlschema.createTableIfNotExists(db)
  db:exec(sqlschema.create_balances_table)
  print("Err: " .. db:errmsg())

  db:exec(sqlschema.create_subscriptions_table)
  print("Err: " .. db:errmsg())
end

-- REGISTRATION

---@param whitelisted boolean
function sqlschema.registerSubscriber(processId, ownerId, whitelisted)
  local stmt = db:prepare [[
    INSERT INTO subscriptions (process_id, owner_id, whitelisted)
    VALUES (:process_id, :owner_id, :whitelisted)
  ]]
  if not stmt then
    error("Failed to prepare SQL statement for registering process: " .. db:errmsg())
  end
  stmt:bind_names({
    process_id = processId,
    owner_id = ownerId,
    whitelisted = whitelisted and 1 or 0
  })
  local _, err = stmt:step()
  stmt:finalize()
  if err then
    error("Err: " .. db:errmsg())
  end
end

function sqlschema.getSubscriber(processId)
  local stmt = db:prepare [[
    SELECT * FROM subscriptions WHERE process_id = :process_id
  ]]
  if not stmt then
    error("Failed to prepare SQL statement for checking subscriber: " .. db:errmsg())
  end
  stmt:bind_names({ process_id = processId })
  return sqlschema.queryOne(stmt)
end

-- SUBSCRIPTION

function sqlschema.subscribeToTopics(processId, topics)
  -- add the topics to the existing topics while avoiding duplicates
  local stmt = db:prepare [[
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
    error("Failed to prepare SQL statement for subscribing to topics: " .. db:errmsg())
  end
  stmt:bind_names({
    process_id = processId,
    topic = topics
  })
  local _, err = stmt:step()
  stmt:finalize()
  if err then
    error("Err: " .. db:errmsg())
  end
end

function sqlschema.unsubscribeFromTopics(processId, topics)
  -- remove the topics from the existing topics
  local stmt = db:prepare [[
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
    error("Failed to prepare SQL statement for unsubscribing from topics: " .. db:errmsg())
  end
  stmt:bind_names({
    process_id = processId,
    topic = topics
  })
  local _, err = stmt:step()
  stmt:finalize()
  if err then
    error("Err: " .. db:errmsg())
  end
end

-- NOTIFICATIONS

function sqlschema.getNotifiableSubscribersForTopic(topic)
  local stmt = db:prepare [[
    SELECT process_id
    FROM subscriptions as subs
    WHERE json_contains(topics, :topic) AND (subs.whitelisted = 1 OR EXISTS (
      SELECT 1
      FROM balances as b
      WHERE b.owner_id = subs.owner_id AND b.balance > 0
    ))
  ]]
  if not stmt then
    error("Failed to prepare SQL statement for getting notifiable subscribers: " .. db:errmsg())
  end
  stmt:bind_names({ topic = topic })
  return sqlschema.queryMany(stmt)
end

-- BALANCES

function sqlschema.updateBalance(ownerId, tokenId, amount, isCredit)
  local stmt = db:prepare [[
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
    error("Failed to prepare SQL statement for updating balance: " .. db:errmsg())
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
    error("Error updating balance: " .. db:errmsg())
  end
end

function sqlschema.getBalanceEntry(ownerId, tokenId)
  local stmt = db:prepare [[
    SELECT * FROM balances WHERE owner_id = :owner_id AND token_id = :token_id
  ]]
  if not stmt then
    error("Failed to prepare SQL statement for getting balance entry: " .. db:errmsg())
  end
  stmt:bind_names({ owner_id = ownerId, token_id = tokenId })
  return sqlschema.queryOne(stmt)
end

-- UTILS

function sqlschema.queryMany(stmt)
  local rows = {}
  for row in stmt:nrows() do
    table.insert(rows, row)
  end
  stmt:reset()
  return rows
end

function sqlschema.queryOne(stmt)
  return sqlschema.queryMany(stmt)[1]
end

function sqlschema.rawQuery(query)
  local stmt = db:prepare(query)
  if not stmt then
    error("Err: " .. db:errmsg())
  end
  return sqlschema.queryMany(stmt)
end

return sqlschema
