checkpoint () {
	cd ~/workspace
    gad -A && gco "checkpoint" && gpu
    cd - > /dev/null
    cd ~/secondbrain
    gad -A && gco "checkpoint" && gpu
	cd - > /dev/null
}
