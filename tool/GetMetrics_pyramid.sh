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
	    ./MiningLogs.sh '1 2 m 3' pyramid 93c76c2d0ae52dbc90aacae68a9efbf00af08b45 2010-12-30
	    ;;
	2)
	    ./MiningLogs.sh '1 2 m 3' pyramid 109fd9d337cbf6c1a8203b2c6006981623e9b1da 2016-12-28
	    ;;
	3)
		./MiningLogs.sh '1 2 m 3' pyramid 90335e28fa7ddbe110b3efab61cde7b256e8055d 2012-12-28
	    ;;
	4)
		./MiningLogs.sh '1 2 m 3' pyramid 23e748078ff1cab23aa1c26dd180d5fc7130988f 2014-12-27
	    ;;
	5)
		./MiningLogs.sh '1 2 m 3' pyramid 5da91483b8e0780ed96aa041a5bea9f9a978de80 2008-12-26
    esac
done

echo ''
echo "$0 $@ done."
date
