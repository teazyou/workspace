checkpoint () {
	cd ~/workspace
    gad -A && gco "checkpoint" && gpu
    cd -
    cd ~/secondbrain
    gad -A && gco "checkpoint" && gpu
	cd -
}
