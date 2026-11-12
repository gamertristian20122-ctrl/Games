#!/bin/bash
# Turns the downloaded human-made CC0 / CC-BY sources into game-ready Ogg files.
# Only gain, a loudness match, a crossfaded loop seam and re-encoding. Nothing synthesised.
set -e
DL=/tmp/claude-0/dl
OUT=/home/user/games/.claude/worktrees/wf_cfbab644-a58-6/new-roguelike/assets/audio
gain_to() {
  local L
  L=$(ffmpeg -hide_banner -nostats -i "$1" -af ebur128 -f null - 2>&1 | grep -E "^\s+I:" | tail -1 | awk '{print $2}')
  python3 -c "print(round($2-($L),1))"
}
music() {
  local g
  g=$(gain_to "$1" -16)
  ffmpeg -hide_banner -loglevel error -y -i "$1" -af "volume=${g}dB,alimiter=limit=0.89:level=false" -ar 44100 -ac 2 -c:a libvorbis -b:a 96k "$OUT/music/$2.ogg"
  echo "music $2 gain $g"
}
amb() {
  local X=$3 D g E
  D=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$1")
  E=$(python3 -c "print($D-$X)")
  g=$(gain_to "$1" "$4")
  ffmpeg -hide_banner -loglevel error -y -i "$1" -i "$1" -i "$1" -filter_complex "[0:a]volume=${g}dB,aresample=44100,aformat=channel_layouts=stereo,atrim=0:$X,asetpts=PTS-STARTPTS,afade=t=in:d=$X:curve=qsin[h];[1:a]volume=${g}dB,aresample=44100,aformat=channel_layouts=stereo,atrim=$E:$D,asetpts=PTS-STARTPTS,afade=t=out:d=$X:curve=qsin[t];[h][t]amix=inputs=2:normalize=0[m];[2:a]volume=${g}dB,aresample=44100,aformat=channel_layouts=stereo,atrim=$X:$E,asetpts=PTS-STARTPTS[bd];[m][bd]concat=n=2:v=0:a=1[o]" -map "[o]" -c:a libvorbis -q:a 2 "$OUT/sfx/amb_$2.ogg"
  echo "amb $2 gain $g dur $D"
}
steps() {
  local i=1
  for n in 0 1 2 3 4; do
    ffmpeg -hide_banner -loglevel error -y -i "$DL/fs/footsteps/$1/$n.ogg" -af "loudnorm=I=-20:TP=-3:linear=true,aresample=44100" -ac 1 -c:a libvorbis -q:a 3 "$OUT/sfx/step_$2_$i.ogg"
    i=$((i+1))
  done
  echo "steps $2"
}
amb "$DL/forest.mp3" woods 1.5 -24
amb "$DL/birds.ogg" birds 1.5 -26
amb "$DL/wd/wind/Wind.ogg" wind 1.2 -25
steps grass grass
steps boots stone
steps gravel sand
steps wood wood
