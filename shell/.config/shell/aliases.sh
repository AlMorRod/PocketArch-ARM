# ~/.config/shell/aliases.sh
# Alias portables, compartidos entre bash y zsh (sintaxis POSIX).
# Se carga desde ~/.bashrc (bash) y desde $ZDOTDIR/.zshrc (zsh).
# Añade aquí los alias que quieras disponibles en cualquier shell.

# --- media-transcribe: transcripción de vídeo ------------------------------
# reels <link> [link2 ...]        -> descarga y transcribe reels de Instagram
# yt <url> [--force] [url2 ...]   -> descarga (mp4+mp3) y transcribe YouTube
alias reels='python3 "/storage/emulated/0/Obsidian/02_Protocolos_Scripts/reels_transcribe.py"'
alias yt='python3 "/storage/emulated/0/Obsidian/02_Protocolos_Scripts/youtube_transcribe.py"'
