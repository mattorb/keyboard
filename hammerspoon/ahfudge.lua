local eventtap = hs.eventtap
local eventTypes = hs.eventtap.event.types
local message = require('keyboard.status-message')

-- If 'a' and 'f' are *both* pressed within this time period, consider this to
-- mean that they've been pressed simultaneously, and therefore we should enter
-- Ah Fudge Mode.
local MAX_TIME_BETWEEN_SIMULTANEOUS_KEY_PRESSES = 0.04 -- 40 milliseconds

local ahFudgeMode = {
  -- caps->ctrl is from karabiner mappings
  statusMessage = message.new('(A)h (F)udge Mode.\n u=prev app switch, i/o = app window switch\n h/j/k/l = first/prev/next/last tab nav\n m/, = prev/next space'),
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

-- Watch for 'u' and switch to previous app (cmd-tab)
ahFudgeModeLastAppTabListener = eventtap.new({ eventTypes.keyDown }, function(event)
  if not ahFudgeMode.active then
    return false
  end

  if event:getCharacters(true):lower() == 'u' then
    hs.osascript.applescript("tell application \"System Events\" to key code 48 using command down")
    return true
  end
end):start()

function isAhFudgeModeActive()
  return ahFudgeMode.active
end

local ahfudge_switcher = require('keyboard.ahfudge-switcher')

switcher = ahfudge_switcher.new() -- default windowfilter: only visible windows, all Spaces
switcher.modsPressed = isAhFudgeModeActive  

--------------------------------------------------------------------------------
-- Watch for h/j/k/l key down events in Ah Fudge Mode, and trigger the
-- corresponding key events to navigate to the previous/next tab respectively
--------------------------------------------------------------------------------
ahFudgeModeTabNavKeyListener = eventtap.new({ eventTypes.keyDown }, function(event)
  if not ahFudgeMode.active then
    return false
  end

  local charactersToKeystrokes = {
    h = { {'cmd'}, '1' },          -- go to first tab
    j = { {'cmd', 'shift'}, '[' }, -- go to previous tab
    k = { {'cmd', 'shift'}, ']' }, -- go to next tab
    l = { {'cmd'}, '9' },          -- go to last tab
  }
  local keystroke = charactersToKeystrokes[event:getCharacters()]

  if keystroke then
    keyUpDown(table.unpack(keystroke))
    return true
  end
end):start()

--------------------------------------------------------------------------------
-- Watch for n/m/,/. key down events in Ah Fudge Mode, and trigger the
-- corresponding key events to navigate spaces.  Requires giving permission to control
-- 'System Events' app the first time it is used.
--------------------------------------------------------------------------------
ahFudgeModeSpaceNavKeyListener = eventtap.new({ eventTypes.keyDown }, function(event)
  if not ahFudgeMode.active then
    return false
  end

  if event:getCharacters() == 'n' then
    hs.osascript.applescript("tell application \"System Events\" to key code 126 using control down")
    return true
  end

  if event:getCharacters() == 'm' then
    hs.osascript.applescript("tell application \"System Events\" to key code 123 using control down")
    return true
  end

  if event:getCharacters() == ',' then
    hs.osascript.applescript("tell application \"System Events\" to key code 124 using control down")
    return true
  end
end):start()