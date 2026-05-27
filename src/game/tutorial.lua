-- Sprint tutorial steps. Each step has:
--   text             - instructional string shown in the overlay bubble
--   advance_condition(gs, state) -> bool  optional; auto-advance when true
--   manual_advance   - true if step requires Continue button click

local Tutorial = {}

local STEPS = {
  {
    text = "Welcome to MegaCorp. This is your JIRA Kanban board. Tickets flow Backlog -> In Progress -> Review -> Done.",
    manual_advance = true,
  },
  {
    text = "On your turn you have AP (Action Points) shown on your HUD row. Every action costs 1 AP. Click Continue.",
    manual_advance = true,
  },
  {
    text = "Click any ticket in the Backlog column to select it.",
    advance_condition = function(gs, state)
      return state.kanban_selected_in_backlog
    end,
  },
  {
    text = "Now click the Claim button at the bottom to take ownership.",
    advance_condition = function(gs, state)
      return #gs.in_progress > 0
    end,
  },
  {
    text = "The ticket moved to In Progress. Click the ticket then click Work to advance it.",
    advance_condition = function(gs, state)
      for _, t in ipairs(gs.in_progress) do
        if t.points_remaining < t.points then return true end
      end
      return false
    end,
  },
  {
    text = "Keep clicking Work until the ticket reaches 0 points remaining.",
    advance_condition = function(gs, state)
      for _, t in ipairs(gs.in_progress) do
        if t.points_remaining == 0 then return true end
      end
      return false
    end,
  },
  {
    text = "Points are 0. Click Submit to send it for Review.",
    advance_condition = function(gs, state)
      return #gs.review > 0
    end,
  },
  {
    text = "Now click the ticket in Review, then click Approve. (Tutorial mode lets you self-approve.)",
    advance_condition = function(gs, state)
      return #gs.done > 0
    end,
  },
  {
    text = "You shipped a ticket and earned Credit. Try a Meeting next (click Meeting).",
    advance_condition = function(gs, state)
      return state.meeting_done
    end,
  },
  {
    text = "Meeting gave you +2 Clout and drew a Dilemma. Pick A (the spite move) or B (the clean choice) -- one of them silently bumps your LinkedIn Score.",
    advance_condition = function(gs, state)
      return state.dilemma_resolved
    end,
  },
  {
    text = "Clout lets you play Sabotage cards. Click Sabotage to see the menu, then close it (nobody to sabotage in tutorial).",
    advance_condition = function(gs, state)
      return state.sabotage_closed
    end,
  },
  {
    text = "Click End Turn to wrap up your turn. In a real game the next player takes over here.",
    advance_condition = function(gs, state)
      return state.end_turn_done
    end,
  },
  {
    text = "Tutorial complete! Click End Game to return to the menu -- or keep playing solo to explore.",
    manual_advance = true,
    is_final = true,
  },
}

function Tutorial.new()
  return {
    step_idx = 1,
    kanban_selected_in_backlog = false,
    meeting_done = false,
    dilemma_resolved = false,
    sabotage_closed = false,
    end_turn_done = false,
  }
end

function Tutorial.current(state)
  return STEPS[state.step_idx]
end

function Tutorial.is_complete(state)
  return state.step_idx > #STEPS
end

function Tutorial.advance(state, gs)
  while not Tutorial.is_complete(state) do
    local step = STEPS[state.step_idx]
    if step.manual_advance then return end
    if step.advance_condition and step.advance_condition(gs, state) then
      state.step_idx = state.step_idx + 1
    else
      return
    end
  end
end

function Tutorial.manual_advance(state)
  local step = STEPS[state.step_idx]
  if step and step.manual_advance then
    state.step_idx = state.step_idx + 1
  end
end

Tutorial.STEPS = STEPS
return Tutorial
