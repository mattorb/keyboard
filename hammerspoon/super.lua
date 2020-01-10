-- luacheck: globals hs hyper
local eventtap = hs.eventtap
local eventTypes = hs.eventtap.event.types
local statusMessage = require('keyboard.status-message')
local helpMessage = require('keyboard.help-message')

-- If 's' and 'd' are *both* pressed within this time period, consider this to
-- mean that they've been pressed simultaneously, and therefore we should enter
-- Super Duper Mode.
local MAX_TIME_BETWEEN_SIMULTANEOUS_KEY_PRESSES = 0.04 -- 40 milliseconds

local superDuperMode = {
  -- caps->ctrl is from karabiner mappings
  statusMessage = statusMessage.new('(S)uper (D)uper Mode.'),
  helpMessage = helpMessage.new('(S)uper (D)uper Mode HELP\ng=menu\n y/u/i/o=home/pgdn/pgup/end\n h/j/k/l=cursor\n n/m/,/.// = mousewheel nudge/click\n a=alt, f=cmd, space=shift, caps=ctrl'),

  enter = function(self)
    if not self.active then
      self.statusMessage:show()
      self.helpTimer = hs.timer.delayed.new(3, function() self.helpMessage:show() end ):start()
    end
    self.active = true
  end,
  reset = function(self)
    self.active = false
    self.isSDown = false
    self.isDDown = false
    self.ignoreNextS = false
    self.ignoreNextD = false
    self.modifiers = {}
    self.statusMessage:hide()
    if not (self.helpTimer == nil) then self.helpTimer:stop() end
    self.helpMessage:hide()
  end,
}
superDuperMode:reset()

superDuperExtendedHelpBumper = eventtap.new({ eventTypes.keyDown}, function(event)
  if superDuperMode.active then
    -- in this case 'start' restarts the countdown timer if already started
    superDuperMode.helpTimer:start()
  end
end):start()


superDuperModeActivationListener = eventtap.new({ eventTypes.keyDown }, function(event)
  -- If 's' or 'd' is pressed in conjuction with any modifier keys
  -- (e.g., command+s), then we're not activating Super Duper Mode.
  if not (next(event:getFlags()) == nil) then
    return false
  end

  local characters = event:getCharacters()

  if characters == 's' then
    if superDuperMode.ignoreNextS then
      superDuperMode.ignoreNextS = false
      return false
    end
    -- Temporarily suppress this 's' keystroke. At this point, we're not sure if
    -- the user intends to type an 's', or if the user is attempting to activate
    -- Super Duper Mode. If 'd' is pressed by the time the following function
    -- executes, then activate Super Duper Mode. Otherwise, trigger an ordinary
    -- 's' keystroke.
    superDuperMode.isSDown = true
    hs.timer.doAfter(MAX_TIME_BETWEEN_SIMULTANEOUS_KEY_PRESSES, function()
      if superDuperMode.isDDown then
        superDuperMode:enter()
      else
        superDuperMode.ignoreNextS = true
        keyUpDown({}, 's')
        return false
      end
    end)
    return true
  elseif characters == 'd' then
    if superDuperMode.ignoreNextD then
      superDuperMode.ignoreNextD = false
      return false
    end
    -- Temporarily suppress this 'd' keystroke. At this point, we're not sure if
    -- the user intends to type a 'd', or if the user is attempting to activate
    -- Super Duper Mode. If 's' is pressed by the time the following function
    -- executes, then activate Super Duper Mode. Otherwise, trigger an ordinary
    -- 'd' keystroke.
    superDuperMode.isDDown = true
    hs.timer.doAfter(MAX_TIME_BETWEEN_SIMULTANEOUS_KEY_PRESSES, function()
      if superDuperMode.isSDown then
        superDuperMode:enter()
      else
        superDuperMode.ignoreNextD = true
        keyUpDown({}, 'd')
        return false
      end
    end)
    return true
  end
end):start()

superDuperModeDeactivationListener = eventtap.new({ eventTypes.keyUp }, function(event)
  local characters = event:getCharacters()
  if characters == 's' or characters == 'd' then
    superDuperMode:reset()
  end
end):start()

--------------------------------------------------------------------------------
-- Watch for key down/up events that represent modifiers in Super Duper Mode
--------------------------------------------------------------------------------
superDuperModeModifierKeyListener = eventtap.new({ eventTypes.keyDown, eventTypes.keyUp }, function(event)
  if not superDuperMode.active then
    return false
  end

  local charactersToModifers = {}
  charactersToModifers['a'] = 'alt'
  charactersToModifers['f'] = 'cmd'
  charactersToModifers[' '] = 'shift'

  local modifier = charactersToModifers[event:getCharacters()]
  if modifier then
    if (event:getType() == eventTypes.keyDown) then
      superDuperMode.modifiers[modifier] = true
    else
      superDuperMode.modifiers[modifier] = nil
    end
    return true
  end
end):start()

--------------------------------------------------------------------------------
-- Activate application menu for 'm', nav with h/j/k/l after that
--------------------------------------------------------------------------------
superDuperModeMenuPopListener = eventtap.new({ eventTypes.keyDown }, function(event)
  if not superDuperMode.active then
    return false
  end
  
  local characters = event:getCharacters()

  if characters == 'g' then
    keyUpDown({'ctrl','fn'}, 'f2')
    return true
  end
end):start()

--------------------------------------------------------------------------------
-- Emit Mousewheel scroll events for for n/m/,/.
--------------------------------------------------------------------------------
superDuperModeMouseKeysListener = eventtap.new({ eventTypes.keyDown }, function(event)
  if not superDuperMode.active then
    return false
  end

  local character = event:getCharacters()

  if     character == 'n' then
    return true, {eventtap.event.newScrollEvent({3, 0}, {}, "line")}
  elseif character == 'm' then
    return true, {eventtap.event.newScrollEvent({0, -3}, {}, "line")}
  elseif character == ',' then
    return true, {eventtap.event.newScrollEvent({0, 3}, {}, "line")}
  elseif character == '.' then
    return true, {eventtap.event.newScrollEvent({-3, 0}, {}, "line")}
  elseif character == '/' then
    local currentpos = hs.mouse.getAbsolutePosition()
    return true, {hs.eventtap.rightClick(currentpos)}
  elseif character == 'b' then
    local currentpos = hs.mouse.getAbsolutePosition()
    return true, {hs.eventtap.leftClick(currentpos)}
  end

end):start()

--------------------------------------------------------------------------------
-- Watch for h/j/k/l key down events in Super Duper Mode, and trigger the
-- corresponding arrow key events
--------------------------------------------------------------------------------
-- Watch for u/i/o/p key down events in Super Duper Mode, and trigger the 
-- corresponding home/pgdn/pgup/end key events
--------------------------------------------------------------------------------
superDuperModeNavListener = eventtap.new({ eventTypes.keyDown }, function(event)
  if not superDuperMode.active then
    return false
  end

  local charactersToKeystrokes = {
    h = 'left',
    j = 'down',
    k = 'up',
    l = 'right',
    y = 'home',
    u = 'pagedown',
    i = 'pageup',
    o = 'end',
  }

  local keystroke = charactersToKeystrokes[event:getCharacters(true):lower()]
  if keystroke then
    local modifiers = {}
    n = 0
    -- Apply the custom Super Duper Mode modifier keys that are active (if any)
    for k, v in pairs(superDuperMode.modifiers) do
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
end):start()

