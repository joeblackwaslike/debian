[ -z "$PS1" ] && return

if [ $TERM != dumb ]
then
    if [ -f "/etc/dircolors" ] ; then
        eval $(dircolors -b /etc/dircolors)

        if [ -f "$HOME/.dircolors" ] ; then
            eval $(dircolors -b $HOME/.dircolors)
        fi
    fi

    c_rst='\[\e[0m\]'
    c_user='\[\e[93m\]'
    c_white='\[\e[97m\]'
    c_path='\[\e[36m\]'
    c_ok='\[\e[92m\]'
    root_mark=''
    [ "$EUID" = 0 ] && root_mark=$'\xef\x8a\x92 '

    alias ls='ls --color=auto --group-directories-first'
    alias grep='grep --color=auto'
    alias egrep='egrep --color=auto'
    alias fgrep='fgrep --color=auto'
    PS1="${c_user}\u ${c_white}in ${c_path}\w${c_rst}\n${c_white}${root_mark}\h ${c_ok}❯${c_rst} "
else
    alias ls="ls -F --group-directories-first"
    PS1="\u in \w\n\h > "
fi

unset c_rst c_user c_white c_path c_ok root_mark
export PS1 LS_COLORS

