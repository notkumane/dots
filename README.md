a checklist for me


xorg-server xorg-xinit xorg-xset xorg-xrandr xcompmgr terminator conky zsh linux-zen-headers (virtualbox-guest-utils) nvidia-dkms i3-gaps xfce4-panel xfce4-goodies
unclutter rofi lxappearance starship feh

git clone https://aur.archlinux.org/paru.git
makepkg -si

pywal nerd-fonts-complete 

git clone https://github.com/zsh-users/zsh-syntax-highlighting.git
echo "source ${(q-)PWD}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ${ZDOTDIR:-$HOME}/.zshrc
