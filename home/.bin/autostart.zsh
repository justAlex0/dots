#!/usr/bin/env zsh

# For the general use
function start {
    # Hotkey daemon
    # [[ ! $(pgrep --exact swhks) ]] && swhks &> /dev/null &
    # [[ ! $(pgrep --exact swhkd) ]] && pkexec swhkd -c "$HOME"/.config/swhkd/swhkdrc &> /dev/null &

    # Music Player Daemon
    [[ ! $(pgrep --exact mpd) ]] && mpd

    # Audio Effects for Pipewire applications
    if [[ -x /usr/bin/easyeffects && ! $(pgrep -x easyeffects) ]]; then
        easyeffects --gapplication-service &
    fi

    # Notification daemon
    [[ ! $(pgrep --exact dunst) ]] && dunst &>/dev/null &

    # Custom daemons
    [[ ! $(pgrep --full daemons/) ]] && fd -tx . ~/.bin/daemons/ -x {}

    gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    gsettings set org.gnome.desktop.interface gtk-theme "Catppuccin-Mocha-Standard-Red-Dark"
    gsettings set org.gnome.desktop.interface icon-theme "breeze-dark"
    gsettings set org.gnome.desktop.interface cursor-theme "Bibata-Original-Classic"
    gsettings set org.gnome.desktop.interface font-name "DejaVu Sans 11"
}

function start_X {
    # Keyboard layout
    setxkbmap -option grp:win_space_toggle -option caps:escape
    setxkbmap -layout us,ru
    # setxkbmap -layout us,ru -variant colemak,

    # Display Power Management Signaling
    xset s off
    xset dpms 130 130 130

    # Screen locker
    [[ ! $(pgrep --exact xautolock) ]] && xautolock -time 2 -locker sxlock &>/dev/null &

    # Compositor
    [[ ! $(pgrep --exact picom) ]] && picom &>/dev/null &

    # Screenshoter
    [[ ! $(pgrep --exact flameshot) ]] && flameshot &>/dev/null &

    # Bar and widgets
    ln -sf ~/.local/bin/eww-x ~/.local/bin/eww
    launch_eww

    # Keyboard layout
    [[ ! $(pgrep --full keyboard-layout.bash) ]] && ~/.bin/keyboard-layout.bash x
}

function start_Wayland {
    # Idle management daemon
    [[ ! $(pgrep --exact swayidle) ]] && swayidle -w \
        timeout 120 'swaylock -f -c 1a1b26 --ring-color 24283b --key-hl-color bb9af7 --inside-color 1a1b26' \
        timeout 130 'hyprctl dispatch dpms off' \
        resume 'hyprctl dispatch dpms on' \
        before-sleep 'swaylock -f -c 1a1b26 --ring-color 24283b --key-hl-color bb9af7 --inside-color 1a1b26' &

    # Bar and widgets
    ln -sf ~/.local/bin/eww-wayland ~/.local/bin/eww
    launch_eww

    # Keyboard layout
    [[ ! $(pgrep --full keyboard-layout.bash) ]] && ~/.bin/keyboard-layout.bash wayland
}

function launch_eww {
    [[ ! $(pgrep --exact eww) ]] && {
        eww daemon &>/dev/null
        eww open bar &>/dev/null
    } &
}

function stop {
    eww kill

    if [[ -x /usr/bin/easyeffects ]]; then
        easyeffects -q
    fi

    pkill --exact dunst

    pkill --exact xautolock
    pkill --exact picom
    pkill --exact flameshot

    pkill --exact swayidle

    pkill --full daemons/
    pkill --full keyboard-layout.bash

}

case "$1" in
"x")
    start
    start_X
    ;;
"wayland")
    start
    start_Wayland
    ;;
"stop") stop ;;
*) exit 1 ;;
esac
