#!/usr/bin/env bash
# shot.sh: pictures of one walking place in the PC look (Forward+, Vulkan), in one line.
#   ./tools/shot.sh <place> <outdir> [extra flags ...]
#   ./tools/shot.sh village /tmp/pics --clock=0.7        # Wickmere by night
#   ./tools/shot.sh elfwood /tmp/pics
#   ./tools/shot.sh village /tmp/pics --nohd             # the same place without the HD light
# Places: village (Wickmere), elfwood, deepwood, glade, beacon, world, dustwatch, suncourt.
# Extra flags go to the game after `--` (e.g. --clock=<0..1>, --hubtalk=<npc>, --nohd).
# Set GL=1 to take them in the phone's renderer (GL Compatibility) instead.
# Software rendering is slow: about one to two and a half minutes a run. The pictures are
# <outdir>/hub_<n>.png (a place with a "tour" gives five, others one).
set -u
if [ $# -lt 2 ]; then
	sed -n '2,11p' "$0"
	exit 1
fi
cd "$(dirname "$0")/.."
PLACE="$1"
OUT="$(mkdir -p "$2" && cd "$2" && pwd)"
shift 2
if [ "${GL:-0}" = "1" ]; then
	RENDER=(--rendering-method gl_compatibility --rendering-driver opengl3)
else
	RENDER=(--rendering-method forward_plus --rendering-driver vulkan)
fi
timeout ${SHOT_TIMEOUT:-700} xvfb-run -a -s "-screen 0 1600x720x24" "${GODOT:-godot}" --path . "${RENDER[@]}" \
	--resolution 1600x720 -- --hub="$PLACE" --nosave --shots="$OUT" "$@" 2>&1 \
	| grep -E "SCRIPT ERROR|SHADER ERROR|^E |\[light\]" || true
ls "$OUT"/hub_*.png 2>/dev/null
