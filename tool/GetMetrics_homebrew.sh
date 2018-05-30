#!/bin/sh

cd get_metrics

date

if [ -z "$1" ]; then
    echo '[ERR] specify number'
    exit
else 
    steps=$1
fi

for step in $steps; do
    case $step in
	1)
	    ./MiningLogs.sh '1 2 m 3' homebrew c25e2cff9c56d0898d2875ff135f85d76332e971 2016-10-10
	    ;;
	2)
	    ./MiningLogs.sh '1 2 m 3' homebrew 8c59d84ab9add84b53b30559532c70ec90998e5a 2015-10-09
	    ;;
	3)
	    ;;
	4)
	    ./MiningLogs.sh '1 2 m 3' homebrew 598de804d04b34cfee685b637c94dae2d1e7d3bd 2009-12-31
	    ;;
    esac
done

echo ''
echo "$0 $@ done."
date
