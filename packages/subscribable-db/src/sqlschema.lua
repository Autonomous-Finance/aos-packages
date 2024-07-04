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
    topics TEXT -- JSON data
);
]]

function sqlschema.createTableIfNotExists(db)
  db:exec(sqlschema.create_balances_table)
  print("Err: " .. db:errmsg())

  db:exec(sqlschema.create_subscriptions_table)
  print("Err: " .. db:errmsg())
end

function sqlschema.registerSubscriber(processId, ownerId, topics)
  local stmt = db:prepare [[
    INSERT INTO subscriptions (process_id, owner_id)
    VALUES (:process_id, :owner_id)
    ON CONFLICT(process_id) DO UPDATE SET
    owner_id = excluded.owner_id,
  ]]
  if not stmt then
    error("Failed to prepare SQL statement for registering process: " .. db:errmsg())
  end
  stmt:bind_names({
    process_id = processId,
    owner_id = ownerId
  })
  local result, err = stmt:step()
  stmt:finalize()
  if err then
    error("Err: " .. db:errmsg())
  end
end

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
