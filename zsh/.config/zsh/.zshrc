[[ -f "$ZDOTDIR/exports.zsh" ]] && source "$ZDOTDIR/exports.zsh"
[[ -f "$ZDOTDIR/history.zsh" ]] && source "$ZDOTDIR/history.zsh"
[[ -f "$ZDOTDIR/aliases.zsh" ]] && source "$ZDOTDIR/aliases.zsh"
[[ -f "$ZDOTDIR/functions.zsh" ]] && source "$ZDOTDIR/functions.zsh"

eval "$(zoxide init zsh)"
eval "$(starship init zsh)"

# Fastfetch solo en el shell de primer nivel (no en panes de tmux ni shells anidados)
[[ -z "$TMUX" ]] && (( SHLVL == 1 )) && command -v fastfetch >/dev/null && fastfetch
