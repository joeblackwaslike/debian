[ -n "${BASH_VERSION-}" ] || return

if [[ -d /etc/environment.d ]]; then
    for f in /etc/environment.d/*; do
        [[ -f $f && -r $f ]] && . "$f"
    done
    names=$(cat /etc/environment.d/* 2>/dev/null | grep -oE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=' | tr -d ' \t=')
    [[ -n $names ]] && export $names
    unset f names
fi
