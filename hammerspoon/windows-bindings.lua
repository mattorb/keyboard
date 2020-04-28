hyper = {"cmd", "alt", "ctrl", "shift"}
nohyper = {"alt"}

return {
  modifiers = nohyper,
  showHelp  = true,
  trigger   = 'w',
  mappings  = {
    { {},         'return', 'maximize' },
    { {},         'space',  'centerWithFullHeight' },
    { {},         'h',      'left' },
    { {},         'j',      'down' },
    { {},         'k',      'up' },
    { {},         'l',      'right' },
    { {'shift'},  'h',      'left40' },
    { {'shift'},  'l',      'right60' },
    { {},         'i',      'upLeft' },
    { {},         'o',      'upRight' },
    { {},         ',',      'downLeft' },
    { {},         '.',      'downRight' },
    { {},         'n',      'nextScreen' },
    { {},         'right',  'moveOneScreenEast' },
    { {},         'left',   'moveOneScreenWest' },
  }
}
