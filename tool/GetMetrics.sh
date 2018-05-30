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
	    ./MiningLogs.sh '1 2 m 3' reddit e4bd50addbb9223cd56e4f2fe141d2674df11fca 2017-01-03
	    ;;
	2)
	    ./MiningLogs.sh '1 2 m 3' reddit a627470a257afe576f1c646379c7af3a3d948704 2016-01-14
	    ;;
	3)
	    ./MiningLogs.sh '1 2 m 3' reddit 8baab09fdeab5be0251f12e0a69bdb74e65be1fe 2015-01-06 
	    ;;
	4)
	    ./MiningLogs.sh '1 2 m 3' reddit ae9b5cadeae76ecf4f10abfcd97a6f61930c9298 2014-01-07
	    ;;
	5)
		./MiningLogs.sh '1 2 m 3' reddit fae2a7651ff522f1ebb56f2b0ac05d77698073b8 2013-01-07
		;;
	6)
		./MiningLogs.sh '1 2 m 3' reddit 256fcd70b8cbfd5fbc92897b10c4190c05b4d440 2012-01-02
		;;
	7)
		./MiningLogs.sh '1 2 m 3' reddit 79d63d14243e957b265a9be106672e814cb6218f 2008-12-17
		;;
    esac
done

echo ''
echo "$0 $@ done."
date
