[[ -f "$ZDOTDIR/exports.zsh" ]] && source "$ZDOTDIR/exports.zsh"
[[ -f "$ZDOTDIR/history.zsh" ]] && source "$ZDOTDIR/history.zsh"
[[ -f "$ZDOTDIR/aliases.zsh" ]] && source "$ZDOTDIR/aliases.zsh"

eval "$(zoxide init zsh)"
eval "$(starship init zsh)"
