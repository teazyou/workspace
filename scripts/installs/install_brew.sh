#!/bin/bash

. $FUNCTIONS/brew.sh

# OH-MY-ZSH
if [ -d "$ZSH" ]; then
	echo $COK"OH-MY-ZSH already installed"$CWH
else
	echo $CW8"installing OH-MY-ZSH..."$CWH
	sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" &> /dev/null
	if [[ $? != 0 ]] ; then
		echo $CKO"OH-MY-ZSH install fail"$CWH
	else
		echo $COK"OH-MY-ZSH install success"$CWH
	fi
fi

xcode-select --install &> /dev/null
if [[ $? != 0 ]] ; then
	echo $COK"XCODE-SELECT already installed"$CWH
else
	echo $CW8"XCODE-SELECT validating license (need sudo)"$CWH
	sudo xcodebuild -license accept
	echo $CW8"XCODE-SELECT install"$CWH
fi

# caskInstall "NGROK" "ngrok"
# brewInstall "TIG" "tig"
# brewInstall "RUBY" "ruby"
# brewInstall "REDIS" "redis"
# caskInstall "MONGODB" "mongodb"
# caskInstall "ALFRED" "alfred"
# caskInstall "POSTMAN" "postman"
# caskInstall "BETTER-TOUCH-TOOL" "bettertouchtool"
# caskInstall "DOCKER" "docker"

brewInstall "PYTHON" "python"

brewInstall "NVM" "nvm"
brewInstall "NPM" "npm"

brewInstall "MYSQL" "mysql"
brewInstall "POSTGRESQL" "postgresql@17"

caskInstall "ITERM" "iterm2"

caskInstall "VSCODE" "visual-studio-code"
caskInstall "BRAVE" "brave-browser"

caskInstall "SPOTIFY" "spotify"
caskInstall "DBEAVER" "dbeaver-community"

caskInstall "KEEPING-YOU-AWAKE" "keepingyouawake"
caskInstall "TRANSMISSION" "transmission"
caskInstall "VLC" "vlc"
caskInstall "NORDVPN" "nordvpn"
caskInstall "BITWARDEN" "bitwarden"
caskInstall "ONYX" "onyx"

# caskInstall "GOOGLE-DRIVE" "google-drive"

echo $COK"Brew update all packages..."$CWH
brew upgrade &> /dev/null

echo $COK"Brew cleanup..."$CWH
brew cleanup &> /dev/null
brew services cleanup &> /dev/null

echo $COK"Install Node with NVM"$CWH
nvm install --lts

echo $COK"Brew list of service at startup (brew services list)"$CWH
brew services list

