# shell-tools

## rad-spinner

Design goals:
- Conform to the following api:
  - has a 'prefix' of 'rad_spinner'
  - the interface is '${prefix}_start' to start the animation.  so rad_spinner_start
  - similarly with rad_spinner_update, to update the text
  - similarly with rad_spinner_stop, to end the spinner and return from the function
- Support drawing arbitrary patterns to a 12x4 "screen" consisting of 12 'braille' unicode characters
- Support defining or generating animations programmatically, based on geometric rules
- Generated patterns are highly organic and look cool
