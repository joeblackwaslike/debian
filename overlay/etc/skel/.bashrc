if ! shopt -q login_shell; then
    for f in /etc/profile.d/*.sh; do
        [ -r "$f" ] && . "$f"
    done
    unset f
fi
