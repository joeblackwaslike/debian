[ -n "${BASH_VERSION-}" ] || return 0

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
    local time="" label="" module=""
    if [[ -z ${minimal-} ]]; then
        time="$(log::get-time) "
        label="${type^^} "
    fi
    if [[ ! $(basename "$0") = 'bash' && -n $(basename "$0") ]]; then
        module="[${3:-$(basename "$0")}] "
    fi
    printf '\e[%sm[%s]\e[0m %s%s%s%s\n' "$color" "$symbol" "$time" "$label" "$module" "$msg" >&2
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
function _get-container-id {
    grep -oE -m1 '[0-9a-f]{64}' /proc/1/cgroup | head -1 | grep . \
        || grep -oE -m1 'containers/[0-9a-f]{64}' /proc/self/mountinfo | head -1 | cut -d/ -f2
}
function clear {
    printf '\033c'
}
function container-id {
    local cid
    if [[ ${1-} =~ ^(h|help)$ ]]; then
        echo "Usage: container-id {short|full|help}"
        return 1
    fi
    cid=$(_get-container-id) && [[ -n $cid ]] || return 1
    case "${1-}" in
        f|full|l|long)
            echo "$cid"
            ;;
        *)
            echo "${cid:0:12}"
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
    else
        return 1
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
    linux::cmd::exists capsh || return 2
    capsh --decode="$(awk '/^CapEff:/ {print $2}' /proc/self/status)" | grep -qw "cap_${name,,}"
}
function linux::cap::is-disabled {
    local rc=0
    linux::cap::is-enabled "$1" || rc=$?
    [[ $rc -eq 1 ]]
}
function linux::cap::show-warning {
    local name="$1"
    local _space=""
    if [[ ! $(basename "$0") = 'bash' && ! -z $(basename "$0") ]]; then
        local _module="[${3:-$(basename $0)}] "
        local _len=${#_module}
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
    [[ ${USE_LONG_HOSTNAME-} == true || ${HOSTNAME-} == *.* ]]
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
    else
        return 1
    fi
}
function shell::is-interactive {
    [[ $- =~ i ]]
}
function shell::is-not-interactive {
    ! shell::is-interactive
}
