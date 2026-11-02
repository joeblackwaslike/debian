[ -n "${BASH_VERSION-}" ] || return

function log::get-time {
    date '+%Y-%m-%d %H:%M:%S'
}
function log::_show-msg {
    local symbol_map
    declare -A symbol_map=(
        [info]='*'
        [warn]='-'
        [error]='x'
    )
    local color_map
    declare -A color_map=(
        [info]='36'
        [warn]='33'
        [error]='31'
    )
    local msg="$1"
    local type="${2:-info}"
    local symbol="${symbol_map[$type]}"
    local color="${color_map[$type]}"
    local time="$(log::get-time) "
    if [[ ! $(basename "$0") = 'bash' && ! -z $(basename "$0") ]]; then
        local module="[${3:-$(basename $0)}] "
    fi
    type+=' '
    if [ ! -z "$minimal" ]; then
        unset time type
    fi
    echo -e "\E[${color}m[${symbol}]\E[0m ${time}${type^^}${module}${msg}" >&2
}
function log::info {
    local msg="$@"
    log::_show-msg "$msg" 'info'
}
function log::error {
    local msg="$@"
    log::_show-msg "$msg" 'error'
}
function log::warn {
    local msg="$@"
    log::_show-msg "$msg" 'warn'
}
function log::m-info {
    local msg="$@"
    local minimal=true
    log::info "$msg"
}
function log::m-warn {
    local msg="$@"
    local minimal=true
    log::warn "$msg"
}
function log::m-error {
    local msg="$@"
    local minimal=true
    log::error "$msg"
}
function clear {
    echo -ne '\0033\0143'
}
function _get-container-id {
    grep -oE -m1 '[0-9a-f]{64}' /proc/1/cgroup | head -1 | grep . \
        || grep -oE -m1 'containers/[0-9a-f]{64}' /proc/self/mountinfo | head -1 | cut -d/ -f2
}
function container-id {
    local cid
    case "$1" in
        s|short)
            _get-container-id | cut -c 1-12
            ;;
        f|full|l|long)
            _get-container-id
            ;;
        h|help)
            echo "Usage $0 {short|full|help}"
            return 1
            ;;
        *)
            container-id short
            ;;
    esac
}
function get-ipv4 {
    local interface="${1:-eth0}"
    if linux::cmd::exists 'ip'; then
        ip -o -f inet addr show $interface | sed 's/.*inet \(.*\)\/.*/\1/'
    elif linux::cmd::exists 'ifconfig'; then
        ifconfig $interface | grep 'inet ' | cut -d':' -f2 | awk '{print $1}'
    elif linux::cmd::exists 'hostname'; then
        hostname -i | head -1
    fi
}
function linux::cmd::exists {
    local cmd="$1"
    hash "$cmd" > /dev/null 2>&1
}
function linux::cmd::does-not-exist {
    local cmd="$1"
    ! hash "$cmd" > /dev/null 2>&1
}
function linux::cap::is-enabled {
    local name="$1"
    capsh --decode="$(awk '/^CapEff:/ {print $2}' /proc/self/status)" | grep -qw "cap_${name,,}"
}
function linux::cap::is-disabled {
    ! linux::cap::is-enabled "$1"
}
function linux::cap::show-warning {
    local name="$1"
    if [[ ! $(basename "$0") = 'bash' && ! -z $(basename "$0") ]]; then
        local _module="[${3:-$(basename $0)}] "
        local _len=${#_module}
        # ((_len+=2))
        local _space=$(printf ' %.0s' $(seq 1 $_len))
    fi
    log::m-warn "The cap CAP_${name^^} is restricted in this container.
    ${_space}It's recommended to run this container with --cap-add ${name^^}"
}
function linux::get-shell-vars {
    local names_only="${1:-false}"
    local _res=$(compgen -v | grep -v ^names_only)
    local _var
    if [[ ! $names_only = true ]]; then
        _res=$(echo "$_res" | while read _var; do printf "%s=%q\n" "$_var" "${!_var}"; done)
    fi
    printf '%s\n' "$_res"
}
function linux::get-shell-var-names {
    linux::get-shell-vars true
}
function linux::get-env-vars {
    local names_only="${1:-false}"
    local _res=$(env | grep -v ^names_only)
    if [[ $names_only = true ]]; then
        _res=$(echo "$_res" | cut -d'=' -f1)
    fi
    printf '%s\n' "$_res"
}
function linux::get-env-var-names {
    linux::get-env-vars true
}
function linux::get-function-names {
    compgen -A function
}
function net::is-long-hostname {
    [[ $USE_LONG_HOSTNAME == true || $ERLANG_HOSTNAME == 'long' || $KUBE_HOSTNAME == 'long' || $HOSTNAME =~ \. ]]
}
function net::is-short-hostname {
    ! net::is-long-hostname
}
function net::get-mtu {
    local interface="${1:-eth0}"
    if linux::cmd::exists 'ip'; then
        ip -o link show $interface | awk '{print $5}'
    elif linux::cmd::exists 'ifconfig'; then
        ifconfig $interface | grep MTU | awk '{print $5}' | cut -d':' -f2
    fi
}
function shell::is-interactive {
    [[ $- =~ i ]]
}
function shell::is-not-interactive {
    ! shell::is-interactive
}
