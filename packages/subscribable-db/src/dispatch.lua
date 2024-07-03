local sqlschema = require('sqlschema')

local dispatch = {}

function dispatch.dispatch(event, payload)
  local subscribersStmt = db:prepare([[
    SELECT s.process_id, s.quote_token_process_id
    FROM top_n_subscriptions s
    JOIN balances b ON s.owner_id = b.owner_id AND b.balance > 0
    WHERE s.last_push_at + s.push_interval >= :now
    ]])
  if not subscribersStmt then
    error("Err: " .. db:errmsg())
  end
  subscribersStmt:bind_names({
    now = now
  })

  local json = require("json")

  print('sending market data updates to consumer processes')

  local marketDataPerQuoteToken = {} -- cache market data per quote token
  local consumers = {}               -- later log subscribers that were updated
  for row in subscribersStmt:nrows() do
    table.insert(consumers, row.process_id)
    local quoteToken = row.quote_token_process_id
    local marketData = marketDataPerQuoteToken[quoteToken]
    if not marketData then
      marketData = sqlschema.getTopNMarketData(quoteToken)
      marketDataPerQuoteToken[quoteToken] = marketData
    end
    ao.send({
      ['Target'] = row.process_id,
      ['Action'] = 'TopNMarketData',
      ['Data'] = json.encode(marketData)
    })
  end
  subscribersStmt:finalize()

  print('sent market data updates to ' .. #consumers .. ' consumer processes')

  local message = {
    ['Target'] = ao.id,
    ['Assignments'] = consumers,
    ['Action'] = 'TopNMarketData',
    ['Data'] = json.encode(marketDataPerQuoteToken)
  }
  ao.send(message)

  print('Dispatched market data to all top N consumers')
end

return dispatch
