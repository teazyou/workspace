# Request

## Context

### This repository

This repository `~/workspace` is my macbook environment configuration. Its a public repository.

The system/environment use link to file in this folders. Any similar config files should be saved here and linked where they belong. The purpose is to centralise all my system setups in one repository for easy backup/export/edit tasks.

### What I want

I am about to reset my macbook and to create an installation.sh script in `./scripts/installs/installation.sh` which is going to setup my system as much as possible automatically.

Currently there is already a script in `./scripts/installs/install_brew.sh` which install all my defaults app by using brew and the helper function in `./functions/brew.sh`

We need to optimize and extend the process so it do more than just installing brew apps. It may require to be done in few steps with some manual entry, example to setup my git password so it can clone the workspace folder by itself.

## Best scenario

What I would like as best scenario.

I use one line command to run remotely the script from my repository, something like

```sh
sh (link to script.sh)
```

And it will do as much as possible, with some manual entry for me.

I will list what it should do, im not sure about the optimal order

- Cloning workspace repository in ~/workspace
- Installing oh-my-zsh
- setup the ~/.zshrc as a link to the ~/workspace/zsh/zshrc.zsh ( and reload from here if possible )
- Install Claude Desktop ( app link https://claude.ai/api/desktop/darwin/universal/dmg/latest/redirect )
- Install claude-code with native installation `curl -fsSL https://claude.ai/install.sh | bash`
- Install cleanmymac ( https://macpaw.com/download/cleanmymac.dmg )
- Install aerospace + borders + sketchybar, do all the links correctly
- All setup file in workspace should be linked to their appropriate place, example by vscode config should be a link to the ./configs/vscode/settings.json
- Check all extention in VS code and create an install_vscode_ext.sh which will re-install all my extention 

The script installation.sh should use different script for different step, example claude desktop and claude-code are saved in install_claude.sh and the installation.sh script runs it when its time to do it. Each steps is properly segmented similar to a code base where we have different files for different functions. everything inside the folder ./scripts/installs

The script should be able to verify which steps is eventually already done to skip it and move to next one without breaking. So we may want some verification, similar to the brew.sh script which verify if an app exist before installing it.

## What you will do

### First

Start by analyzing what I may have miss from my current system that should be included in the install script, can I copy my macbook system settings also, is there anything else I should consider ?

You will list anything that could be missing and check with me what should be included or not (if you find anything).

We move next step once I validated

### Second

Make a research to see whats possible or not from what I would like to achieve, whats the best option and if not possible, is there any alternative options ?

Once finish, review this research with me and ask me what decision to make

We move next step once I validated

### Third

You execute all the plan to create this new installation scripts and all the sub-scripts





