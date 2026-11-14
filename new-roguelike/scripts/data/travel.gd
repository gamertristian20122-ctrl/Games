extends RefCounted
## TRAVEL BETWEEN THE LIGHTS (the quality pass, package 07). Once a beacon burns, the knight can step into its
## light and step out at any other light he has lit, or at Wickmere's watch-fire: no more walking the whole
## map to bring word to Captain Hale. Words are placeholders the owner may rewrite (keep the ids).
##
## STOPS: one row each.
##   "id"      short name, used in the save-free "do" {"travel": id}
##   "land"    the beacon that must burn for this stop to work ("tale:lit:<land>"); "" = always (Wickmere)
##   "place"   the place id, "at" where the knight steps out (a free spot just south of the light)
##   "name"    how the stop is called on the button
##   "person"  the id of the thing in that place that is spoken to ("travel": true is set on its row by
##             places.gd; "add": a row to add when the place has no such thing yet, as the watch-fire)
## A module (scripts/data/more.gd) may bring more stops with a function stops() -> Array of such rows.
## This file reads only the save, so anything may preload it.

const More = preload("res://scripts/data/more.gd")

const STOPS := [
	{"id": "wickmere", "land": "", "place": "village", "at": Vector2(552, 300), "name": "Wickmere's watch-fire", "person": "watchfire",
		"add": {"id": "watchfire", "name": "The watch-fire", "title": "", "ghost": true, "pos": Vector2(552, 284), "top": 26, "role": "chat",
			"text": "The watch-fire of Wickmere. The watch feeds it day and night, and it has never once gone out."}},
	{"id": "elfwood", "land": "elfwood", "place": "beacon", "at": Vector2(240, 238), "name": "The Beacon of the Wood", "person": "beacon"},
	{"id": "sands", "land": "sands", "place": "suncourt", "at": Vector2(280, 238), "name": "The Beacon of the Sands", "person": "sandbeacon"},
	{"id": "cinder", "land": "cinder", "place": "cinderpeak", "at": Vector2(240, 238), "name": "The Beacon of the Mountains", "person": "cinderbeacon"},
]

const OFFER := "Step into the light: %s"                 ## the button (the stop's name goes in)
const ARRIVE := "The light sets you down: %s"            ## the small card on arriving
const HINT := "The light of a burning beacon reaches every other. Step into it to travel."      ## under the words, once a beacon burns
const FIRE_DARK := "They say the first king could step from fire to fire, when the beacons burned."      ## the watch-fire before any beacon is lit


static func all() -> Array:
	return STOPS + More.stops()


static func row(id: String) -> Dictionary:
	for s: Dictionary in all():
		if String(s["id"]) == id:
			return s
	return {}


## Does this stop work now (its beacon burns)?
static func open(s: Dictionary) -> bool:
	return String(s["land"]) == "" or Save.hub_get("tale:lit:" + String(s["land"])) > 0


## Is any beacon lit at all (before that nobody travels anywhere)?
static func any_lit() -> bool:
	for s: Dictionary in all():
		if String(s["land"]) != "" and open(s):
			return true
	return false


## The stop spoken to through this person of this place ({} = none).
static func stop_at(place_id: String, person: String) -> Dictionary:
	for s: Dictionary in all():
		if String(s["place"]) == place_id and String(s["person"]) == person:
			return s
	return {}


## Where the knight may go from this stop: every OTHER stop whose light burns. Nothing while this
## stop's own light is dark.
static func from(here: Dictionary) -> Array:
	if here.is_empty() or not open(here) or not any_lit():
		return []
	return all().filter(func(s: Dictionary) -> bool: return String(s["id"]) != String(here["id"]) and open(s))


## places.gd calls this for every place: the things that are stops get "travel": true (and are added
## when the place has none, as Wickmere's watch-fire).
static func fit(place_id: String, place: Dictionary) -> void:
	for s: Dictionary in all():
		if String(s["place"]) != place_id:
			continue
		var found := false
		for p: Dictionary in place.get("people", []):
			if String(p.get("id", "")) == String(s["person"]):
				p["travel"] = true
				found = true
		if not found and s.has("add"):
			var add: Dictionary = (s["add"] as Dictionary).duplicate()
			add["travel"] = true
			if not place.has("people"):
				place["people"] = []
			(place["people"] as Array).append(add)
