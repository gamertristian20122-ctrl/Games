#!/usr/bin/env bash
# check.sh: the health check for the game that ships (the story RPG), all without a screen.
#   1. imports assets
#   2. compiles EVERY script (dev/compile_all.gd: also the ones only loaded on demand, such as the battle screen)
#   3. checks the data tables (dev/validate.gd)
#   4. checks the saved games: safe write, backup, three slots, the old save taken over, the title's
#      rows and the pause menus (--uitour=save)
#   5. plays the whole story with a bot (--uitour=tale): every step, every story battle
#   6. plays chapter one's three story battles in a row many times (dev/battle_sim.tscn --chain)
# It FAILS (exit code 1) on any script error, any failed check, or a test that never reports.
# Usage:  ./tools/check.sh            (run it from anywhere; about 3 minutes)
#         ./tools/check.sh --old      also the six bot runs of the retired roguelike rooms
#         ./tools/check.sh --quick    steps 1 to 4 only (about 20 seconds)
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG="$(mktemp -d)"
FAIL=0
OLD=0
QUICK=0
for a in "$@"; do
	case "$a" in
		--old) OLD=1 ;;
		--quick) QUICK=1 ;;
	esac
done

# prints the errors of a log (if any) and marks the check as failed
errors() {
	if grep -E "SCRIPT ERROR|Parse Error|ERROR: data check" "$1" > /dev/null; then
		echo "  FAILED: errors in the output (see $1):"
		grep -E -A 3 "SCRIPT ERROR|Parse Error|ERROR: data check" "$1" | head -24
		FAIL=1
	fi
}

echo "== import"
timeout 300 "$GODOT" --headless --path . --import > "$LOG/import.log" 2>&1 || timeout 300 "$GODOT" --headless --path . --import > "$LOG/import.log" 2>&1

echo "== every script compiles"
timeout 200 "$GODOT" --headless --path . --script res://dev/compile_all.gd > "$LOG/compile.log" 2>&1
grep "COMPILE DONE" "$LOG/compile.log" | tail -n 1
if ! grep -q "COMPILE DONE .* bad=0$" "$LOG/compile.log"; then
	echo "  FAILED: a script does not compile (see $LOG/compile.log):"
	grep -E -B 3 "COMPILE FAIL" "$LOG/compile.log" | head -40
	FAIL=1
fi

echo "== data tables"
timeout 120 "$GODOT" --headless --path . res://dev/world_test.tscn -- --validate > "$LOG/validate.log" 2>&1
grep "VALIDATE" "$LOG/validate.log" | tail -n 1
if ! grep -q "VALIDATE OK" "$LOG/validate.log" || grep -E "SCRIPT ERROR|ERROR:" "$LOG/validate.log" > /dev/null; then
	grep -E -A 2 "SCRIPT ERROR|ERROR:|VALIDATE" "$LOG/validate.log" | head -24
	FAIL=1
fi

echo "== saved games, title, pause"
timeout 200 "$GODOT" --headless --path . -- --uitour=save > "$LOG/save.log" 2>&1
grep -E "^\[save\] (ok|FAIL):" "$LOG/save.log" | tail -n 1
if ! grep -q "^\[save\] ok:" "$LOG/save.log" || grep -q "\[save\] FAIL" "$LOG/save.log"; then
	echo "  FAILED: the save check (see $LOG/save.log):"
	grep "\[save\] FAIL" "$LOG/save.log" | head -20
	FAIL=1
fi
errors "$LOG/save.log"

if [ $QUICK -eq 0 ]; then
	echo "== the story, played by a bot"
	timeout 600 "$GODOT" --headless --path . -- --uitour=tale --nosave > "$LOG/tale.log" 2>&1
	grep "^\[tale\] done:" "$LOG/tale.log" | tail -n 1
	if ! grep -q "^\[tale\] done: .* 0 failed" "$LOG/tale.log" || grep -q "FAIL" "$LOG/tale.log"; then
		echo "  FAILED: the story tour did not finish cleanly (see $LOG/tale.log):"
		grep "FAIL" "$LOG/tale.log" | head -20
		tail -n 3 "$LOG/tale.log"
		FAIL=1
	fi
	errors "$LOG/tale.log"

	echo "== story battles in a row"
	timeout 300 "$GODOT" --headless --path . res://dev/battle_sim.tscn -- --nosave --chain > "$LOG/chain.log" 2>&1
	code=$?
	grep "in a row" "$LOG/chain.log" | tail -n 2
	if [ $code -ne 0 ] || ! grep -q "in a row" "$LOG/chain.log"; then
		echo "  FAILED: the battle simulation did not report (exit $code, see $LOG/chain.log)"
		FAIL=1
	fi
	errors "$LOG/chain.log"
fi

if [ $OLD -eq 1 ]; then
	echo "== bot runs (the retired roguelike rooms)"
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
fi

if [ $FAIL -ne 0 ]; then
	echo "CHECK FAILED  (logs: $LOG)"
	exit 1
fi
echo "CHECK PASSED"
rm -rf "$LOG"
