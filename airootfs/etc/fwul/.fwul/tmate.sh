#!/bin/bash
########################################################
# Simple convenient tmate starter
########################################################

tmate new-session -d "echo '.. please wait .. connecting..' && sleep 7 && tmate show-messages |tail -n1 | sed 's/\(.*ssh session:\)\(.*\)/SHARE THIS LINE (press q to quit): \2/g' |less" \; split-window -d \; attach


