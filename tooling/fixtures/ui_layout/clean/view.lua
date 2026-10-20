local M = {}

function M.draw(c, state)
  c.page_header.draw({ id = "main", title = state.title })
  c.card_row.draw({ id = "cards", cards = state.cards })
  c.list.draw({ id = "rows", items = state.rows })
end

return M
