class_name PlayerInput
extends RefCounted
## What the keeper is being asked to do on this tick of the game.
##
## A human fills this in from the keyboard, mouse or controller.
## The test bot fills in the very same thing, so both play by the same rules.

var move := Vector2.ZERO      # which way to walk (length 0 to 1)
var aim := Vector2.RIGHT      # which way to point (length 1)
var shoot := false            # is the fire button held?
var dash := false             # was the dash button pressed just now?
