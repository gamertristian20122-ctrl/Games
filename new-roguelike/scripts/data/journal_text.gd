extends RefCounted
## THE JOURNAL'S WORDS (quality pass P11): every new word of the Journal screen (scripts/ui/journal.gd)
## and the World map screen (scripts/ui/world_map.gd). All of it is a PLACEHOLDER for the owner to
## rewrite (keep the keys). Names of people and places are the game's own (tale.gd, places.gd).
##
## RECAP      one short paragraph per chapter (the index of quest_list.gd CHAPTERS), shown above that
##            chapter's steps once the chapter has begun
## PLACE_NAME what the Secrets tab calls a place (the names the places already carry)
## PLACE_SIGN which name on the world map stands for a place (the knight's ember is put there when he
##            is inside it; secrets and errand marks gather there)
## STEP_SIGN  where the story's next step is on the world map (by Tale.STEPS index): the brass ring
## GIVER_AT   where each person who gives errands is found
## BANDS      a monster's health in words: [health of its row at most, the word]

const WORDS := {
	"title": "Journal",
	"tabs": [["story", "Story"], ["errands", "Errands"], ["secrets", "Secrets"], ["monsters", "Monsters"], ["records", "Records"]],
	"done": "Done", "now": "Now", "next_step": "What to do now",
	"story_hint": "Every step of the tale so far. The gold one is where it stands now.",
	"errand_hint": "Side errands people have asked of you.",
	"errand_unknown": "Not met yet. Somebody, somewhere, needs a hand.",
	"errand_taken": "Taken", "errand_done": "Handed in", "errand_ready": "Done: go back to %s",
	"errand_from": "Asked by %s, %s.", "errand_reward": "Reward: %s",
	"secrets_hint": "Chests and hidden things nobody tells you about.",
	"secrets_place_unseen": "A place you have not been to yet.",
	"secrets_found": "Found here: %s", "secrets_left": "%d still hidden here.", "secrets_all": "Nothing left to find here.",
	"monsters_hint": "Every kind of monster you have beaten.",
	"monster_unknown": "Not met yet.",
	"monster_beaten": "Beaten %d times", "monster_beaten_one": "Beaten once",
	"boss_line": "A great foe of the story. It has moves of its own; watch what it means to do.",
	"records_hint": "Your road so far, in numbers.",
	"rec_time": "Time played", "rec_level": "Level", "rec_coins": "Coins in the chest", "rec_beacons": "Beacons lit",
	"rec_beaten": "Monsters beaten", "rec_bosses": "Great foes beaten", "rec_kinds": "Kinds of monster met",
	"rec_errands": "Errands handed in", "rec_secrets": "Secrets found", "rec_skills": "Skills learned",
	"rec_wins": "Battles won",
	"of": "%d of %d",
	"map_title": "World Map",
	"map_unknown": "?",
	"map_you": "Ember: you", "map_goal": "Ring: the story goes here", "map_errand": "An errand leads here",
	"map_gold": "Gold: work to do", "map_grey": "Grey: still shut", "map_green": "Green: done",
	"map_inside": "Inside: %s",
	"map_secrets": "%d/%d",
	"map_zoom": "Zoom", "map_move": "Look around",
}

const RECAP := [
	"Aldous came to Wickmere under Hollow Hill, where the lamps are still kept lit. The beacon of the Elfwood had gone dark, and the wood had gone wrong with it.",
	"With one beacon burning again, Captain Hale sent him east across the wide world, to the diggers' town of Dustwatch and the sands where the second shard was carried.",
	"Two beacons burn. The third shard went north-east, past the Cinder Pass, to the smiths of Emberfall and the dark beacon above their forge.",
	"Three beacons burn. The last shard lies somewhere in the Sunken Archive.",
]

const PLACE_NAME := {
	"room": "Your room", "hall": "The Hollow Flagon", "village": "Wickmere", "elfwood": "The Elfwood Road",
	"glade": "The Rune Glade", "deepwood": "The Deepwood", "beacon": "The Beacon of the Wood", "world": "The Wide World",
	"dustwatch": "Dustwatch", "suncourt": "The Sunwell", "emberfall": "Emberfall", "cinderpeak": "The Cinder Stair",
}

const PLACE_SIGN := {
	"room": "Hollow Hill", "hall": "Hollow Hill", "village": "Hollow Hill",
	"elfwood": "The Elfwood", "glade": "The Elfwood", "deepwood": "The Elfwood", "beacon": "The Elfwood",
	"dustwatch": "Dustwatch", "suncourt": "Dustwatch", "emberfall": "Emberfall", "cinderpeak": "Emberfall",
}

const STEP_SIGN := [
	"Hollow Hill", "The Elfwood", "The Elfwood", "The Elfwood", "The Elfwood", "The Elfwood", "Hollow Hill",
	"Dustwatch", "Dustwatch", "Dustwatch", "The Bone Dunes", "Dustwatch", "Dustwatch", "Hollow Hill",
	"Dustwatch", "The Cinder Pass", "Emberfall", "Emberfall", "Emberfall", "Emberfall", "Emberfall", "Hollow Hill",
	"The Sunken Archive",
]

const GIVER_AT := {
	"patron": ["Old Wenna", "the Hollow Flagon"], "ysolde": ["Ysolde", "Wickmere"], "marta": ["Marta", "Wickmere"],
	"brandt": ["Sergeant Brandt", "Wickmere"], "wicker": ["Wicker", "the Elfwood Road"], "odo": ["Brother Odo", "Wickmere"],
	"nib": ["Nib", "Dustwatch"], "imre": ["Sister Imre", "Dustwatch"],
}

const BANDS := [[7.0, "Frail"], [11.0, "Sturdy"], [15.0, "Tough"], [99999.0, "Huge"]]

## (P11) THE KNIGHT SCREEN's new words: the Items page and the skills told by their battle rules
## (scripts/ui/knight.gd). %s / %d are filled in by the screen.
const KNIGHT := {
	"items_tab": "Items",
	"items_head": "In the pack", "use_head": "Use on", "coins_head": "Coins", "arms_head": "Arms",
	"items_hint": "Choose a supply, then who it is for. It works as it does in a battle.",
	"items_none": "The pack is empty. Sellers in the towns have more.",
	"item_have": "In the pack: %d (it holds %d).",
	"item_pick": "Now choose who it is for.",
	"item_used": "Used: %s on %s (+%d %s).",
	"item_used_all": "Used: %s (+%d %s in all).",
	"item_choose_first": "Choose a supply first.",
	"coins": "%d coins in the chest",
	"arms_line": "%s: %s (%d of %d)",
	"health_head": "Health now",
	"hp": "health", "mp": "mana",
	# skills by their battle rules
	"aim_foes": "every monster", "aim_foe": "one monster", "aim_friend": "one friend", "aim_party": "your whole side",
	"hits": "Hits %s for %d%% of a blow.",
	"heals": "Heals %s: %d%% of their health.",
	"stun": "Stun chance %d%%.",
	"status": "%d%% chance: %s (%s)",
	"bonus": "x%s against the %s.",
	"safe": "You guard as you land.", "pierce": "Goes through defence.", "cleanse": "Takes every ill off your side.",
	"mana": "%s, %d mana.",
	"rank": "Rank %d of %d.", "rank_next": "Next rank (a teacher, %d coins): %s.", "rank_top": "Highest rank.",
	"rank_power": "+%d%% to its blow", "rank_heal": "+%d%% to its healing", "rank_stun": "+%d points of stun chance",
	"no_rule": "Not used in battles.",
}
