#!/bin/bash
# Claude Code status line (minimal, 2 lines, TokyoNight Night colors)
#   1: folder · git branch, changes, ahead/behind · lines changed · (right) CPU, RAM, battery
#   2: model · effort · context · plan usage (5-hour and weekly limits) · (right) git author
input=$(cat)

j() { jq -r "$1 // empty" <<<"$input" 2>/dev/null; }

# TokyoNight Night palette (24-bit color)
rgb() { printf '\033[38;2;%d;%d;%dm' "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}"; }
r=$(printf '\033[0m')
blue=$(rgb 7aa2f7); purple=$(rgb bb9af7); cyan=$(rgb 7dcfff); fg=$(rgb a9b1d6); muted=$(rgb 565f89)
green=$(rgb 9ece6a); yellow=$(rgb e0af68); red=$(rgb f7768e)
# Color by percent: green < 50%, yellow < 80%, red >= 80%
color() { if [ "$1" -ge 80 ]; then printf '%s' "$red"; elif [ "$1" -ge 50 ]; then printf '%s' "$yellow"; else printf '%s' "$green"; fi; }
sep="${muted}  ${r}"

# Folder (home shown as ~) and git
dir=$(j '.workspace.current_dir'); dir=${dir:-$(j '.cwd')}; dir=${dir:-$PWD}
line="${blue}${dir/#$HOME/~}${r}"

branch=$(git -C "$dir" branch --show-current 2>/dev/null)
if [ -n "$branch" ]; then
  line="$line${sep}${muted}branch:${r} ${purple}$branch${r}"
  changes=$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  [ "$changes" -gt 0 ] && line="$line ${yellow}●$changes${r}"
  counts=$(git -C "$dir" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)
  if [ -n "$counts" ]; then
    behind=${counts%%[[:space:]]*}; ahead=${counts##*[[:space:]]}
    [ "$ahead" -gt 0 ] && line="$line ${green}↑$ahead${r}"
    [ "$behind" -gt 0 ] && line="$line ${red}↓$behind${r}"
  fi
fi

# Model and context window
model=$(j '.model.display_name'); model=${model:-Claude}
size=$(j '.context_window.context_window_size'); size=${size:-200000}
used=$(j '.context_window.current_usage
  | if . then (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0) else null end')
if [ -z "$used" ]; then
  transcript=$(j '.transcript_path')
  if [ -f "$transcript" ]; then
    used=$(tail -n 300 "$transcript" | jq -Rn '
      [inputs | fromjson? | select(.type == "assistant" and .message.usage) | .message.usage]
      | last // {}
      | (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)' 2>/dev/null)
  fi
fi
used=${used:-0}; pct=$((used * 100 / size))
# Model, effort and context start line 2
line2="${cyan}$model${r}"
effort=$(j '.effort.level')
[ -n "$effort" ] && line2="$line2 ${yellow}⚡$effort${r}"
line2="$line2 ${muted}ctx${r} $(color "$pct")$pct%${r}"

# Tokens used by the last prompt: ↑ new input (not counting cache reads), ↓ output
transcript=$(j '.transcript_path')
if [ -f "$transcript" ]; then
  turn=$(tail -n 3000 "$transcript" | jq -Rnr '
    [inputs | fromjson?] as $all
    | ([$all | to_entries[] | select(.value.type == "user" and (.value.message.content
        | (type == "string") or (type == "array" and any(.[]; .type == "text")))) | .key] | last) as $start
    | [$all[($start // 0):][] | select(.type == "assistant" and .message.usage)]
    | group_by(.message.id) | map(last.message.usage)
    | "\(map((.input_tokens // 0) + (.cache_creation_input_tokens // 0)) | add // 0) \(map(.output_tokens // 0) | add // 0)"' 2>/dev/null)
  k() { awk -v n="$1" 'BEGIN { if (n >= 1000) printf "%.1fk", n / 1000; else printf "%d", n }'; }
  if [ -n "$turn" ]; then
    tin=${turn% *}; tout=${turn#* }
    line2="$line2 ${muted}tokens${r} ${fg}↑$(k "$tin") ↓$(k "$tout")${r}"
  fi
fi

added=$(j '.cost.total_lines_added'); removed=$(j '.cost.total_lines_removed')
[ -n "$added$removed" ] && line="$line${sep}${muted}change:${green}+${added:-0}${muted}/${red}-${removed:-0}${r}"

# Plan usage: 5-hour and weekly limits, each with its reset time
# Short clock time: 2AM, 2:30PM (minutes only when not :00)
clock() {
  local h m p
  read -r h m p <<<"$(LC_ALL=C date -r "$1" '+%l %M %p')"
  [ "$m" != "00" ] && h="$h:$m"
  printf "%s%s" "$h" "$p"
}
# usage <label> <percent> <reset epoch> [day format]
usage() {
  local out=" ${muted}$1${r} $(color "$2")$2%${r}"
  [ -n "$3" ] && out="$out ${muted}↻ ${4:+$(LC_ALL=C date -r "$3" "$4") }$(clock "$3")${r}"
  printf "%s" "$out"
}
five=$(j '.rate_limits.five_hour.used_percentage | floor')
week=$(j '.rate_limits.seven_day.used_percentage | floor')
[ -n "$five$week" ] && line2="$line2${sep}${fg}usage${r}"
[ -n "$five" ] && line2="$line2$(usage 5h "$five" "$(j '.rate_limits.five_hour.resets_at')") "
[ -n "$week" ] && line2="$line2$(usage 7d "$week" "$(j '.rate_limits.seven_day.resets_at')" +%a)"

# Right side: CPU and memory use of this Mac
cores=$(sysctl -n hw.ncpu 2>/dev/null)
cpu=$(ps -A -o %cpu= 2>/dev/null | awk -v c="${cores:-1}" '{s += $1} END {v = int(s / c); print (v > 100 ? 100 : v)}')
mem=$(vm_stat 2>/dev/null | awk -v total="$(sysctl -n hw.memsize 2>/dev/null)" -v page="$(pagesize 2>/dev/null)" '
  /Pages active/ || /Pages wired/ || /occupied by compressor/ {gsub(/\./, "", $NF); used += $NF}
  END {if (total > 0) print int(used * page * 100 / total)}')
right=""
[ -n "$cpu" ] && right="${muted}CPU${r} $(color "$cpu")$cpu%${r}"
[ -n "$mem" ] && right="${right:+$right  }${muted}RAM${r} $(color "$mem")$mem%${r}"
# Battery (none on desktop Macs): red < 20%, yellow < 50%, else green
batt=$(pmset -g batt 2>/dev/null | grep -o '[0-9]*%' | head -1 | tr -d %)
if [ -n "$batt" ]; then
  if [ "$batt" -lt 20 ]; then bc=$red; elif [ "$batt" -lt 50 ]; then bc=$yellow; else bc=$green; fi
  right="${right:+$right  }${muted}BAT${r} $bc$batt%${r}"
fi

# Right side of line 2: the git author for this repository
author=$(git -C "$dir" config user.name 2>/dev/null)
email=$(git -C "$dir" config user.email 2>/dev/null)
right2=""
[ -n "$author" ] && right2="${muted}author:${r} ${blue}$author${r}"
[ -n "$email" ] && right2="${right2:-${muted}author:${r}} ${muted}<$email>${r}"

# The script has no terminal of its own, so ask the terminal of Claude Code (a parent process)
pid=$PPID
for _ in 1 2 3 4; do
  tty=$(ps -o tty= -p "$pid" 2>/dev/null | tr -d " ")
  if [ -n "$tty" ] && [ "$tty" != "??" ]; then
    cols=$( { stty -f "/dev/$tty" size; } 2>/dev/null | awk '{print $2}'); break
  fi
  pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d " "); [ -z "$pid" ] && break
done
cols=${cols:-${COLUMNS:-120}}
visible() { perl -CS -pe 's/\e\[[0-9;]*m//g' <<<"$1" | perl -CS -ne 'chomp; print length'; }
# pad <left> <right>: the right side sits at the terminal's right edge
pad() {
  [ -z "$2" ] && { printf "%s" "$1"; return; }
  local gap=$(( cols - $(visible "$1") - $(visible "$2") - 6 ))
  [ "$gap" -lt 2 ] && gap=2
  printf "%s%*s%s" "$1" "$gap" '' "$2"
}
line=$(pad "$line" "$right")
line2=$(pad "$line2" "$right2")

echo "${fg}$line${r}"
[ -n "$line2" ] && echo "$line2"
exit 0
