#!/bin/bash
# Plays automatic test runs with the bot and writes docs/balance_report.md.
#
#   tools/run_bot.sh            30 runs for each of the three skill levels
#   tools/run_bot.sh 100        100 runs each
#
# Set GODOT to your Godot 4.7 program if "godot" is not on your PATH:
#   GODOT=/path/to/Godot_v4.7.2-stable_linux.x86_64 tools/run_bot.sh
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
RUNS="${1:-30}"
rm -rf bot_out
mkdir -p bot_out
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
for skill in new ok pro; do
	"$GODOT" --headless --fixed-fps 60 --path . -- --bot --skill=$skill --runs="$RUNS" --seed=1 --out=bot_out/$skill.json &
done
wait
"$GODOT" --headless --path . -- --report=bot_out --out=docs/balance_report.md
echo "Done. Open docs/balance_report.md"
