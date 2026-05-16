#!/bin/bash

sh $SCRIPTS/dstore.sh silent
[[ $? != 0 ]] && exit 1;
sh $SCRIPTS/git/gstatus.sh
[[ $? != 0 ]] && exit 1;
# si aucune list a push on push tout
if [ $# -lt 1 ]
then
	# recupere la raison du commit
	echo $CW8"Enter commit description or leave blank for cancel.."$CWH
	read -r commit
	# cancel si aucune raison
	if [ ! "$commit" ]
	then
		echo $CKO"Canceled!"$CWH
		exit 0
	fi
# Si un argument transmit on push tout avec comme commit l'argument transmit
else
	commit=$*
fi
# Execute l'operation
echo $CW8"git commit -m \""$commit"\""$CWH
git commit -m "$commit"
echo $COK"Done! (not pushed!)"$CWH
exit 0
