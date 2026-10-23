#!/usr/bin/env bash
# Statusline de Claude Code: modelo, límites 5h/7d, contexto y costo.
# Requiere jq. Los límites llegan solo con plan Pro/Max.
input=$(cat)

# Colores: paleta Material Monokai (truecolor)
R=$'\e[0m'; DIM=$'\e[2m'; BOLD=$'\e[1m'
GREEN=$'\e[38;2;166;226;46m'
YELLOW=$'\e[38;2;230;219;116m'
RED=$'\e[38;2;249;38;114m'
CYAN=$'\e[38;2;102;217;239m'
GRAY=$'\e[38;2;103;117;124m'

color() { if [ "$1" -ge 80 ]; then printf '%s' "$RED"
          elif [ "$1" -ge 50 ]; then printf '%s' "$YELLOW"
          else printf '%s' "$GREEN"; fi; }

bar() { local pct=$1 w=10 filled i out=""
        filled=$(( (pct * w + 50) / 100 ))
        for ((i=0; i<w; i++)); do [ $i -lt $filled ] && out+="█" || out+="░"; done
        printf '%s' "$out"; }

fmt_left() { local s=$1
             [ "$s" -le 0 ] && { printf 'ya'; return; }
             local d=$((s/86400)) h=$(((s%86400)/3600)) m=$(((s%3600)/60))
             if   [ $d -gt 0 ]; then printf '%dd %dh' $d $h
             elif [ $h -gt 0 ]; then printf '%dh %02dm' $h $m
             else printf '%dm' $m; fi; }

fmt_tok() { local n=$1
            if   [ "$n" -ge 1000000 ]; then printf '%d.%dM' $((n/1000000)) $(((n%1000000)/100000))
            elif [ "$n" -ge 1000 ];    then printf '%dk' $((n/1000))
            else printf '%d' "$n"; fi; }

seg() { local label=$1 pct=$2 resets=$3 left c
        left=$(( resets - $(date +%s) ))
        [ "$left" -le 0 ] && pct=0
        c=$(color "$pct")
        printf '%s%s%s %s%s%s %s%3d%%%s %s↻ %s%s' \
          "$GRAY" "$label" "$R" "$c" "$(bar "$pct")" "$R" "$c" "$pct" "$R" "$DIM" "$(fmt_left "$left")" "$R"; }

IFS=$'\t' read -r p5 r5 p7 r7 model ctx ctx_tok ctx_size cents < <(echo "$input" | jq -r '[
  (.rate_limits.five_hour.used_percentage // 0 | floor),
  (.rate_limits.five_hour.resets_at // 0),
  (.rate_limits.seven_day.used_percentage // 0 | floor),
  (.rate_limits.seven_day.resets_at // 0),
  (.model.display_name // "?"),
  (.context_window.used_percentage // 0 | floor),
  ((.context_window.current_usage // {}) | (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)),
  (.context_window.context_window_size // 0),
  ((.cost.total_cost_usd // 0) * 100 | round)
] | @tsv')

SEP=" ${GRAY}│${R} "
printf '%s%s%s' "$CYAN$BOLD" "$model" "$R"
if [ "$r5" != "0" ]; then
  printf '%s' "$SEP"; seg "5h" "$p5" "$r5"
  printf '%s' "$SEP"; seg "7d" "$p7" "$r7"
fi
printf '%s%sctx %s%s/%s %d%%%s' "$SEP" "$GRAY" "$(color "$ctx")" "$(fmt_tok "$ctx_tok")" "$(fmt_tok "$ctx_size")" "$ctx" "$R"
printf '%s%s$%d.%02d%s' "$SEP" "$GRAY" $((cents/100)) $((cents%100)) "$R"
