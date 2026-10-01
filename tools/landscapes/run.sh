#!/bin/zsh
# Run one landscape build windowed, under the shared GPU lock, with a hard cap.
#   tools/landscapes/run.sh <name> [--movie] [--headless]
# Output: /private/tmp/zs-landscapes/<name>/ (stills, report.txt, run.log, and
# take.avi with --movie).
set -u
name=$1; shift
movie=0; headless=0
for a in "$@"; do
  [[ $a == --movie ]] && movie=1
  [[ $a == --headless ]] && headless=1
done
G="$HOME/Applications/Godot.app/Contents/MacOS/Godot"
root=${0:A:h:h:h}
out=/private/tmp/zs-landscapes/$name
mkdir -p $out
lock=/tmp/zenscape-godot-gpu.lock
if (( ! headless )); then
  while ! mkdir $lock 2>/dev/null; do
    owner=$(cat $lock/pid 2>/dev/null)
    if ! pgrep -qf 'MacOS/Godot' || { [[ -n $owner ]] && ! kill -0 $owner 2>/dev/null; }; then
      rm -rf $lock; continue
    fi
    sleep 5
  done
  echo $$ > $lock/pid
  trap 'rm -rf $lock' EXIT
fi
args=(--path $root)
if (( headless )); then args+=(--headless --fixed-fps 60)
else args+=(--windowed --resolution 1280x720)
  (( movie )) && args+=(--write-movie $out/take.avi)
fi
perl -e 'alarm shift; exec @ARGV' 600 $G $args -s res://tools/landscapes/$name.gd -- --modeless --no-title 2>&1 | head -c 4000000 > $out/run.log
code=${pipestatus[1]}
grep -E "^LANDSCAPE|SCRIPT ERROR|^ERROR|USER ERROR" $out/run.log | grep -v is_finite | head -120
echo "exit $code"
exit $code
