class_name Pal
## The game's colours, all in one place.
##
## The art is black-and-white, so colour carries meaning:
##   pale cream = you, cyan = your echo, warm yellow = your shots,
##   red-pink = danger, gold = rewards. Each floor adds one accent colour.

const INK := Color("0b0f1a")        # background
const INK_SOFT := Color("141a2b")   # panels
const PAPER := Color("f4ead2")      # the keeper and main text
const DIM := Color("7b86a6")        # quiet text
const FAINT := Color("2a3350")      # floor specks, outlines

const ECHO := Color("7ff6ff")       # the echo and everything it does
const EMBER := Color("ffd166")      # the keeper's shots
const DANGER := Color("ff5d6c")     # enemy shots and warnings
const GOLD := Color("ffcf5c")       # rewards
const HEART := Color("ff6b7d")
const GOOD := Color("8bea8f")

# Status colours shown on enemies.
const BURN := Color("ff9a3c")
const CHILL := Color("9fd8ff")
const BRINE := Color("9be36b")
const SHOCK := Color("fff07a")

# Item rarity colours (common, uncommon, rare).
const RARITY := [Color("cfd6e6"), Color("7fd1ff"), Color("ffcf5c")]
