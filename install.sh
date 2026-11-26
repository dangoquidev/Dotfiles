#!/usr/bin/env bash
# Symlink-based dotfiles manager (manifest: links.txt)
#
#   ./install.sh                     interactive menu (whiptail), or install everything
#   ./install.sh install [group…]    create links (all groups by default)
#   ./install.sh uninstall [group…]  remove links and restore backups
#   ./install.sh status              state of every link
#   -n / --dry-run                   show what would happen, change nothing

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$DOTFILES/links.txt"
BACKUP_ROOT="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/backup"
DRY_RUN=false

G='\033[0;32m' B='\033[0;34m' Y='\033[1;33m' R='\033[0;31m' N='\033[0m'
info() { echo -e "${B}::${N} $*"; }
ok()   { echo -e "${G}  ✓${N} $*"; }
warn() { echo -e "${Y}  !${N} $*"; }
err()  { echo -e "${R}  ✗${N} $*" >&2; }
run()  { if $DRY_RUN; then echo "  [dry-run] $*"; else "$@"; fi; }

# --- manifest ---------------------------------------------------------------
entries() {  # print "group src dest" for the requested groups
    local want=" $* "
    grep -vE '^\s*(#|$)' "$MANIFEST" | while read -r group src dest; do
        if [[ $# -eq 0 || "$want" == *" $group "* ]]; then
            echo "$group $DOTFILES/$src $HOME/$dest"
        fi
    done
}
all_groups() { grep -vE '^\s*(#|$)' "$MANIFEST" | awk '{print $1}' | uniq; }

check_groups() {
    local g known; known=" $(all_groups | tr '\n' ' ') "
    for g in "$@"; do
        [[ "$known" == *" $g "* ]] || { err "unknown group: $g (available: $known)"; exit 1; }
    done
}

# --- hooks ------------------------------------------------------------------
pre_hook() {
    case "$1" in
        spicetify)
            if [[ -d /opt/spotify && ! -w /opt/spotify ]]; then
                warn "spicetify: granting write access to /opt/spotify (sudo)"
                run sudo chmod a+wr /opt/spotify
                run sudo chmod -R a+wr /opt/spotify/Apps
            fi ;;
    esac
}

post_hook() {
    case "$1" in
        fish)
            if command -v fish >/dev/null; then
                info "fish: fisher + plugins (fish_plugins)"
                run fish -c 'functions -q fisher; or begin
                    curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
                    and fisher install jorgebucaran/fisher
                end; fisher update' || warn "fisher update failed"
            fi ;;
        spicetify)
            if command -v spicetify >/dev/null; then
                info "spicetify: apply"
                run spicetify apply || run spicetify backup apply || warn "spicetify apply failed"
            fi ;;
        hypr)
            if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
                run hyprctl reload >/dev/null && ok "hyprland reloaded"
            fi ;;
    esac
}

# --- actions ----------------------------------------------------------------
link_one() {
    local src="$1" dest="$2" backup_dir="$3"

    [[ -e "$src" ]] || { err "missing source: $src"; return; }

    if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
        ok "${dest/#$HOME/\~} (already linked)"
        return
    fi

    if [[ -L "$dest" ]]; then
        run rm "$dest"
    elif [[ -e "$dest" ]]; then
        local bak="$backup_dir/${dest#$HOME/}"
        run mkdir -p "$(dirname "$bak")"
        run mv "$dest" "$bak"
        warn "backup: ${dest/#$HOME/\~} → ${bak/#$HOME/\~}"
    fi

    run mkdir -p "$(dirname "$dest")"
    run ln -s "$src" "$dest"
    ok "${dest/#$HOME/\~} → ${src#$DOTFILES/}"
}

do_install() {
    check_groups "$@"
    local backup_dir; backup_dir="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
    local groups=("$@"); [[ ${#groups[@]} -eq 0 ]] && mapfile -t groups < <(all_groups)
    local g group src dest
    for g in "${groups[@]}"; do
        info "$g"
        pre_hook "$g"
        while read -r group src dest; do link_one "$src" "$dest" "$backup_dir"; done < <(entries "$g")
        post_hook "$g"
    done
    [[ -d "$backup_dir" ]] && info "previous files backed up to ${backup_dir/#$HOME/\~}"
    return 0
}

do_uninstall() {
    check_groups "$@"
    local group src dest rel latest
    while read -r group src dest; do
        if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
            run rm "$dest"
            rel="${dest#$HOME/}"
            # restore the most recent backup that contains this path
            latest="$(ls -1d "$BACKUP_ROOT"/*/"$rel" 2>/dev/null | sort | tail -n1 || true)"
            if [[ -n "$latest" ]]; then
                run mv "$latest" "$dest"
                ok "${dest/#$HOME/\~} restored"
            else
                ok "${dest/#$HOME/\~} unlinked (no backup)"
            fi
        fi
    done < <(entries "$@")
}

do_status() {
    local group src dest
    while read -r group src dest; do
        local d="${dest/#$HOME/\~}"
        if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
            echo -e "${G}linked ${N} [$group] $d"
        elif [[ -L "$dest" ]]; then
            echo -e "${Y}other  ${N} [$group] $d → $(readlink "$dest")"
        elif [[ -e "$dest" ]]; then
            echo -e "${Y}exists ${N} [$group] $d (local file, not linked)"
        else
            echo -e "${R}missing${N} [$group] $d"
        fi
    done < <(entries)
}

menu() {
    command -v whiptail >/dev/null || { do_install; return; }
    local opts=() g
    for g in $(all_groups); do opts+=("$g" "" ON); done
    local sel
    sel=$(whiptail --title "Dotfiles" --checklist "SPACE to toggle, ENTER to confirm" \
        20 60 12 "${opts[@]}" 3>&1 1>&2 2>&3) || exit 0
    # shellcheck disable=SC2086
    do_install ${sel//\"/}
}

# --- main -------------------------------------------------------------------
args=()
for a in "$@"; do
    case "$a" in
        -n|--dry-run) DRY_RUN=true ;;
        -h|--help)    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)            args+=("$a") ;;
    esac
done
set -- "${args[@]+"${args[@]}"}"

case "${1:-}" in
    "")          menu ;;
    install)     shift; do_install "$@" ;;
    uninstall)   shift; do_uninstall "$@" ;;
    status)      do_status ;;
    *)           err "unknown command: $1"; exit 1 ;;
esac
