#!/bin/bash
USAGE="USAGE: $0 [ -make ] [ -x SANA_EXE ] [ list of tests to run, defaults to regression-tests/*/*.sh ]"
NL='
'
die() { echo "$USAGE$NL FATAL ERROR: $@" >&2; exit 1
}
warn() { echo "WARNING: $@" >&2;
}
not() { if eval "$@"; then return 1; else return 0; fi
}
PATH=`pwd`:`pwd`/scripts:$PATH
export PATH
export HOST=`hostname|sed 's/\..*//'`

SANA_EXE=./sana
MAKE=false
while true; do
    case "$1" in
    -make) MAKE=true; shift;;
    -x) [ -x "$2" -o "$MAKE" = true ] || die "unknown argument '$2'"
	SANA_EXE="$2"; shift 2;;
    -*) die "unknown option '$1";;
    *) break;;
    esac
done

export SANA_EXE
NUM_FAILS=0
CORES=${CORES:=`cpus 2>/dev/null || echo 4`}
MAKE_CORES=$CORES
[ `hostname` = Jenkins ] && MAKE_CORES=2 # only use 2 cores to make on Jenkins
if $MAKE ; then
    for EXT in `grep '^ifeq (' Makefile | sed -e 's/.*(//' -e 's/).*//' | grep -v MAIN | sort -u` ''; do
	ext=`echo $EXT | tr A-Z a-z`
	[ "$EXT" = "" ] || EXT="$EXT=1"
	make clean
	if not make -k -j$MAKE_CORES $EXT; then
	    (( NUM_FAILS+=1000 ))
	    warn "make '$EXT' failed"
	fi
	[ $NUM_FAILS -gt 0 ] && warn "Cumulative NUM_FAILS is $NUM_FAILS"
    done
fi

if [ $# -eq 0 ]; then
    set regression-tests/*/*.sh
fi
for r
do
    REG_DIR=`dirname "$r"`
    NEW_FAILS=0
    export REG_DIR
    echo --- running test $r ---
    if "$r"; then
	:
    else
	NEW_FAILS=$?
	(( NUM_FAILS+=$NEW_FAILS ))
    fi
    echo --- test $r incurred $NEW_FAILS failures, cumulative failures is $NUM_FAILS ---
done
echo Number of failures: $NUM_FAILS
exit $NUM_FAILS
