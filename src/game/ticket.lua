-- A Ticket is one card in the JIRA Kanban. Plain data (id, title, type,
-- points, reward, modifiers, hidden_trait) plus column state and the
-- five operations that move it across the board: claim, work,
-- submit_for_review, approve, reject.

local Ticket = {}
Ticket.__index = Ticket

local function copy_modifiers(src)
  local out = {}
  if src then
    for k, v in pairs(src) do out[k] = v end
  end
  return out
end

local function new(opts)
  return setmetatable({
    id = opts.id,
    title = opts.title,
    type = opts.type or "feature",
    points = opts.points or 1,
    reward = opts.reward or 1,
    modifiers = copy_modifiers(opts.modifiers),
    hidden_trait = opts.hidden_trait,
    column = "backlog",
    points_remaining = opts.points or 1,
    owner = nil,
    reviewer = nil,
  }, Ticket)
end

function Ticket:has_modifier(name)
  return self.modifiers[name] == true
end

function Ticket:claim(player_idx)
  assert(self.column == "backlog",
    "claim requires backlog; current column: " .. self.column)
  self.owner = player_idx
  self.column = "in_progress"
end

function Ticket:work()
  assert(self.column == "in_progress",
    "work requires in_progress; current column: " .. self.column)
  if self.points_remaining > 0 then
    self.points_remaining = self.points_remaining - 1
  end
end

function Ticket:submit_for_review()
  assert(self.column == "in_progress",
    "submit_for_review requires in_progress; current column: " .. self.column)
  assert(self.points_remaining == 0,
    "submit_for_review requires points_remaining == 0; got " .. tostring(self.points_remaining))
  self.column = "review"
end

function Ticket:approve(reviewer_idx)
  assert(self.column == "review",
    "approve requires review; current column: " .. self.column)
  self.column = "done"
  self.reviewer = reviewer_idx
end

function Ticket:reject()
  assert(self.column == "review",
    "reject requires review; current column: " .. self.column)
  self.column = "in_progress"
  self.points_remaining = self.points
  self.reviewer = nil
end

return {
  new = new,
}
