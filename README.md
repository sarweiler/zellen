# conway

A sequencer for Monome norns based on Conway's Game of Life.

## Usage

* Grid: enter/modify cell pattern
* KEY2: advance generation
* KEY3: delete board

### Modes

Set the play mode on the parameters screen.
* reborn (default): Play a note for every cell that was born or reborn (= has exactly three neighbors), regardless of the previous state of the cell
* born: Play a note for every cell that was born (has exactly three neighbors and was not alive in the previous generation)
* ghost: Play a note for every cell that is dying(has less than two or more than three neighbors)

## Midi
Set the midi device number (default: 1) and midi velocity (default: 100) in the parameters screen.
