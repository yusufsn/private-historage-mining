 #!/bin/sh

if [ -z "$1" ]; then
    steps="1"
else 
    steps=$1
fi

if [ -z "$2" ]; then
    echo "[ERR] No parameters"
    exit
else
    echo "args $2 $3 $4"
    TARG=$2
    TAG=$3
    TIME=$4

    WD=`pwd`
    GIT_WORK=$WD/../../historage/$TARG
    OUT_DIR=$WD/../../result/$TARG
fi

CUT_DAYS=365

for step in $steps; do
    case $step in
	1)
	    echo "[00] preparing"
	    if [ -d $OUT_DIR ]; then
		echo 'dir OK.'
	    else
		mkdir $OUT_DIR
	    fi
	    git --git-dir=$GIT_WORK/.git branch | grep \* | tr -d '\* ' | tr -d '\n' > $OUT_DIR/now_head
	    ;;
	2)
	    echo "[02] git checkout $TAG"
	    git --git-dir=$GIT_WORK/.git --work-tree=$GIT_WORK checkout -q $TAG
	    ;;
	m)
	    echo "[0m] mining for methods..."
	    find $GIT_WORK -type f | grep '\[MT\]' | grep 'body$' | \
		sed -e "s|^$GIT_WORK/||" | grep -v 'test' > $OUT_DIR/files.txt
	    wc -l $OUT_DIR/files.txt
	    ./perl/MeasureModules.pl $GIT_WORK $OUT_DIR/files.txt $OUT_DIR/${TIME}.csv $CUT_DAYS
	    rm -rf $OUT_DIR/files.txt
	    ;;
	3)
	    echo "[03] git checkout HEAD"
	    HEAD=$(cat "$TARG_RES_DIR/now_head")
	    git --git-dir=$GIT_WORK/.git --work-tree=$GIT_WORK checkout -q $HEAD
	    rm -f "$OUT_DIR/now_head"
	    ;;
    esac
done

echo ''
echo "$0 $@ done."
