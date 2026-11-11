# Pixel Crawler roster proposal

Behaviours are the files in `scripts/entities/ai/`: brute, charger, chaser, exploder, flyer, hopper,
shooter, spreader, summoner. Ids are the `pc_*` sprite ids in `pc_cast.json`. The pack has no boss
sprites: each floor's boss is a normal creature drawn at double size (scale 2, nearest-neighbour).

| Floor | Creature (sprite id) | Suits behaviour | Why |
|---|---|---|---|
| 1 The Crypt (undead) | pc_skeleton_base | chaser | plain walker, the floor's filler |
| 1 | pc_skeleton_rogue | charger | hooded, quick lunging pose |
| 1 | pc_skeleton_warrior | brute | armoured, slower and tougher |
| 1 | pc_skeleton_mage | shooter | robed caster |
| 1 | pc_zombie_base | chaser | shambler |
| 1 | pc_zombie_overweight | exploder | bloated body that bursts |
| 1 | pc_zombie_banshee | flyer | ghost hair, can drift over pits |
| 1 | pc_bat_small | flyer | small swarm bat (use run = Move as its flying idle) |
| 1 BOSS | pc_zombie_muscle x2 | brute boss | big red zombie; 2nd choice: pc_skeleton_warrior x2 |
| 2 The Warrens (brutes, vermin) | pc_rat_base | chaser | sewer rat filler |
| 2 | pc_rat_rogue | charger | dagger rat |
| 2 | pc_rat_mage | shooter | caster rat |
| 2 | pc_rat_warrior | brute | armoured rat |
| 2 | pc_orc_base | chaser | goblin-orc |
| 2 | pc_orc_rogue | hopper | small and jumpy |
| 2 | pc_orc_shaman | summoner | calls rats or fungi |
| 2 | pc_fungus_heavy | exploder | spore cap that bursts |
| 2 BOSS | pc_orc_warrior x2 | brute boss | shield and axe; 2nd choice: pc_rat_warrior x2 |
| 3 The Ashen Halls (fire, stone) | pc_stone_base | brute | rock walker |
| 3 | pc_stone_broken | chaser | cracked, glowing, fragile |
| 3 | pc_stone_lava | spreader | lava body, fire spray |
| 3 | pc_mummy_base | chaser | desert dead in hot halls |
| 3 | pc_mummy_warrior | charger | blade mummy |
| 3 | pc_mummy_mage | shooter | caster |
| 3 | pc_mummy_rogue | hopper | quick leaper |
| 3 | pc_bat_fur | flyer | big bat (96 px source) |
| 3 BOSS | pc_stone_golem x2 | brute boss | furnace-chest golem; 2nd choice: pc_stone_lava x2 |
| 4 The Pit (keepers of the dungeon) | pc_royal_soldier | chaser | guard |
| 4 | pc_royal_knight | brute | heavy guard |
| 4 | pc_royal_archer | shooter | crossbow guard |
| 4 | pc_royal_priest | summoner | heals / calls guards |
| 4 | pc_scholar_censor | spreader | keeper-scholar with tomes |
| 4 | pc_scholar_cataloguer | shooter | book thrower |
| 4 | pc_statue_masculine / _feminine / _old | charger | statues that come alive |
| 4 BOSS | pc_medusa x2 | spreader + summoner boss (stone gaze, calls statues) | 2nd choice: pc_scholar_director x2 |

Familiar candidates: **pc_bat_small** (first choice; flies, 4-frame idle is upside-down so use the
Move loop), **pc_fungus_immature** (tiny hopping mushroom).

Spares for elites, variety or later floors: pc_elf_base / druid / hunter / ranger (Fairy Forest),
pc_bandit_fighter / scout / sorcerer / tracker (Hideout), pc_scholar_researcher, pc_scholar_director,
pc_fungus_immature / old / long, pc_zombie_muscle (if not the boss).

Shopkeeper candidates (idle only): pc_npc_tavern_a, pc_npc_tavern_b (and their `_hold` versions holding
a tray), pc_npc_peasant_a.

Heroes: pc_knight, pc_rogue, pc_wizard (Free Pack, idle/run/death, no hit) and pc_hunter (Cemetery,
idle/run/hit + three attacks, no death). Weapons are separate items drawn rotated toward the aim.
