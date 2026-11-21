[ -n "${BASH_VERSION-}" ] || return 0

if [[ -d /etc/environment.d ]]; then
    for f in /etc/environment.d/*; do
        [[ -f $f && -r $f ]] && . "$f"
    done
    names=$(cat /etc/environment.d/* 2>/dev/null | grep -oE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=' | tr -d ' \t=') || true
    [[ -n $names ]] && export $names
    unset f names
fi
