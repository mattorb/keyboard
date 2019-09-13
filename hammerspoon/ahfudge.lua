local eventtap = hs.eventtap
local eventTypes = hs.eventtap.event.types
local message = require('keyboard.status-message')

-- If 'a' and 'f' are *both* pressed within this time period, consider this to
-- mean that they've been pressed simultaneously, and therefore we should enter
-- Ah Fudge Mode.
local MAX_TIME_BETWEEN_SIMULTANEOUS_KEY_PRESSES = 0.04 -- 40 milliseconds

local ahFudgeMode = {
  -- caps->ctrl is from karabiner mappings
  statusMessage = message.new('(A)h (F)udge Mode.\n i=window-prev, o=window-next\n h=home, j=pgdn, k=pgup, l=end'),
  enter = function(self)
    if not self.active then self.statusMessage:show() end
    self.active = true
  end,
  reset = function(self)
    self.active = false
    self.isADown = false
    self.isFDown = false
    self.ignoreNextA = false
    self.ignoreNextF = false
    self.modifiers = {}
    self.statusMessage:hide()
  end,
}
ahFudgeMode:reset()


ahFudgeModeActivationListener = eventtap.new({ eventTypes.keyDown }, function(event)
  -- If 'a' or 'f' is pressed in conjuction with any modifier keys
  -- (e.g., command+s), then we're not activating Ah Fudge Mode.
  if not (next(event:getFlags()) == nil) then
    return false
  end

  local characters = event:getCharacters()

  if characters == 'a' then
    if ahFudgeMode.ignoreNextA then
      ahFudgeMode.ignoreNextA = false
      return false
    end
    -- Temporarily suppress this 'a' keystroke. At this point, we're not sure if
    -- the user intends to type an 'a', or if the user is attempting to activate
    -- Ah Fudge Mode. If 'f' is pressed by the time the following function
    -- executes, then activate Ah Fudge Mode. Otherwise, trigger an ordinary
    -- 'a' keystroke.
      ahFudgeMode.isADown = true
    hs.timer.doAfter(MAX_TIME_BETWEEN_SIMULTANEOUS_KEY_PRESSES, function()
      if ahFudgeMode.isFDown then
        ahFudgeMode:enter()
      else
        ahFudgeMode.ignoreNextA = true
        keyUpDown({}, 'a')
        return false
      end
    end)
    return true
  elseif characters == 'f' then
    if ahFudgeMode.ignoreNextF then
      ahFudgeMode.ignoreNextF = false
      return false
    end
    -- Temporarily suppress this 'f' keystroke. At this point, we're not sure if
    -- the user intends to type a 'f', or if the user is attempting to activate
    -- Ah Fudge Mode. If 'a' is pressed by the time the following function
    -- executes, then activate Ah Fudge Mode. Otherwise, trigger an ordinary
    -- 'f' keystroke.
    ahFudgeMode.isFDown = true
    hs.timer.doAfter(MAX_TIME_BETWEEN_SIMULTANEOUS_KEY_PRESSES, function()
      if ahFudgeMode.isADown then
        ahFudgeMode:enter()
      else
        ahFudgeMode.ignoreNextF = true
        keyUpDown({}, 'f')
        return false
      end
    end)
    return true
  end
end):start()

ahFudgeModeDeactivationListener = eventtap.new({ eventTypes.keyUp }, function(event)
  local characters = event:getCharacters()
  if characters == 'a' or characters == 'f' then
    ahFudgeMode:reset()
  end
end):start()

--------------------------------------------------------------------------------
-- Watch for key down/up events that represent modifiers in Ah Fudge Mode
--------------------------------------------------------------------------------
ahFudgeModeModifierKeyListener = eventtap.new({ eventTypes.keyDown, eventTypes.keyUp }, function(event)
  if not ahFudgeMode.active then
    return false
  end

  local charactersToModifers = {}

  local modifier = charactersToModifers[event:getCharacters()]
  if modifier then
    if (event:getType() == eventTypes.keyDown) then
      ahFudgeMode.modifiers[modifier] = true
    else
      ahFudgeMode.modifiers[modifier] = nil
    end
    return true
  end
end):start()

--------------------------------------------------------------------------------
-- Watch for h/j/k/l key down events in Ah Fudge Mode, and trigger the
-- corresponding nav key events
--------------------------------------------------------------------------------
ahFudgeModeNavListener = eventtap.new({ eventTypes.keyDown }, function(event)
  if not ahFudgeMode.active then
    return false
  end

  local charactersToKeystrokes = {
    h = 'home',
    j = 'pagedown',
    k = 'pageup',
    l = 'end',
  }

  local keystroke = charactersToKeystrokes[event:getCharacters(true):lower()]
  if keystroke then
    local modifiers = {}
    n = 0
    -- Apply the custom Ah Fudge Mode modifier keys that are active (if any)
    for k, v in pairs(ahFudgeMode.modifiers) do
      n = n + 1
      modifiers[n] = k
    end
    -- Apply the standard modifier keys that are active (if any)
    for k, v in pairs(event:getFlags()) do
      n = n + 1
      modifiers[n] = k
    end

    keyUpDown(modifiers, keystroke)
    return true
  end

  if event:getCharacters(true):lower() == 'i' then
    switcher:previous()
    return true
  end 

  if event:getCharacters(true):lower() == 'o' then
    switcher:next()
    return true
  end 

end):start()

function isAhFudgeModeActive()
  return ahFudgeMode.active
end

local ahfudge_switcher = require('keyboard.ahfudge-switcher')

switcher = ahfudge_switcher.new() -- default windowfilter: only visible windows, all Spaces
switcher.modsPressed = isAhFudgeModeActive  
