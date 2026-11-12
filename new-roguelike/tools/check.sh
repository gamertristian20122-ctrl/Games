#!/usr/bin/env bash
# check.sh: the quick health check for the world half of the game.
#   1. imports assets            2. checks that every script compiles and every data table is sane
#   3. lets the bot play 6 seeded runs (all three heroes), about 240 game seconds each at 8x speed
# It FAILS (exit code 1) if any script error shows up or if the bot never clears a room.
# Usage:  ./tools/check.sh            (run it from anywhere)
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG="$(mktemp -d)"
FAIL=0

echo "== import"
timeout 300 "$GODOT" --headless --path . --import > "$LOG/import.log" 2>&1 || timeout 300 "$GODOT" --headless --path . --import > "$LOG/import.log" 2>&1

echo "== scripts and data tables"
timeout 120 "$GODOT" --headless --path . res://dev/world_test.tscn -- --validate > "$LOG/validate.log" 2>&1
grep "VALIDATE" "$LOG/validate.log" | tail -n 1
if ! grep -q "VALIDATE OK" "$LOG/validate.log" || grep -E "SCRIPT ERROR|ERROR:" "$LOG/validate.log" > /dev/null; then
	grep -E -A 2 "SCRIPT ERROR|ERROR:|VALIDATE" "$LOG/validate.log" | head -24
	FAIL=1
fi

echo "== bot runs"
CLEARED=0
i=0
for spec in "knight 11" "witch 12" "robber 13" "knight 14" "witch 15" "robber 16"; do
	set -- $spec
	i=$((i + 1))
	out="$LOG/run_$i.log"
	timeout 240 "$GODOT" --headless --path . res://dev/world_test.tscn -- --autotest --nosave --hero="$1" --seed="$2" --speed=8 --time=240 > "$out" 2>&1
	code=$?
	result="$(grep "AUTOTEST RESULT" "$out" | tail -n 1)"
	echo "run $i hero=$1 seed=$2 exit=$code ${result#AUTOTEST RESULT }"
	if [ $code -ne 0 ] || [ -z "$result" ]; then
		echo "  FAILED: the run did not finish cleanly (see $out)"
		FAIL=1
	fi
	if grep -E "SCRIPT ERROR|ERROR:" "$out" > /dev/null; then
		echo "  FAILED: errors in the output:"
		grep -E -A 3 "SCRIPT ERROR|ERROR:" "$out" | head -20
		FAIL=1
	fi
	n="$(grep -c "room_cleared" "$out")"
	CLEARED=$((CLEARED + n))
done
echo "rooms cleared in total: $CLEARED"
if [ "$CLEARED" -eq 0 ]; then
	echo "FAILED: the bot never cleared a room"
	FAIL=1
fi

if [ $FAIL -ne 0 ]; then
	echo "CHECK FAILED  (logs: $LOG)"
	exit 1
fi
echo "CHECK PASSED"
rm -rf "$LOG"
