checkpoint () {
	echo $CW8"[ checkpoint ] ~/workspace"$CWH
	cd ~/workspace
    gad -A && gco "checkpoint" && gpu
    cd - > /dev/null
	echo $CW8"[ checkpoint ] ~/secondbrain"$CWH
    cd ~/secondbrain
    gad -A && gco "checkpoint" && gpu
	cd - > /dev/null
}
