#!/bin/bash
USAGE="$0 [ ITERS minutes-per-iter [ measure-spec [ cores ] ] ]
    That is:
    with no arguments, we use default ITERS, minutes-per-iter, and ms3 as the measure.
    With 2 arguments, you can specify number of iters and their duration
    A third optional argument allows you to specify the measure to optimized.
    A fourth optional argumnet allows you to specify the number of simultaneous cores to use (minimun 1, max... whatever)
    Specifying only one argument, or more than three, is incorrect usage.
    "
echo() { /bin/echo "$@"
}
die() { echo "DIR is $DIR"; trap "" 0 1 2 3 15; (echo "$USAGE"; echo "FATAL ERROR: $@") >&2; exit 1
}
[ -x "${EXE:=./sana}.multi" ] || die "can't find executable '$EXE.multi'"
CORES=${CORES:=`./scripts/cpus 2>/dev/null || echo 4`}
if [ "$CORES" -eq 0 ]; then CORES=1; fi
PATH="`pwd`/scripts:$PATH"
export PATH
DIR=`mktemp -d /tmp/syeast.XXXXXXXXX`
MINSUM=0.25
MEASURE="-ms3 1 -ms3_type 1"
 trap "/bin/rm -rf $DIR" 0 1 2 3 15
if [ `hostname` = Jenkins ]; then
    ITERS=256; minutes=0.1
else
    ITERS=99; minutes=0.1
fi
[ "$#" -eq 0 -o "$#" -ge 2 -a "$#" -le 4 ] || die "incorrect number of arguments $#"
[ "$#" -eq 4 ] && CORES=$4
[ "$#" -ge 3 ] && MEASURE="$3"
[ "$#" -ge 2 ] && ITERS=$1 minutes=$2

/bin/rm -rf networks/*/autogenerated /var/preserve/autogen* /tmp/autogen* networks/*-shadow*
echo "Running $ITERS iterations of $minutes minute(s) each, optimizing measure '$MEASURE' on $CORES cores to $DIR"
./multi-pairwise.sh -frugal -archive tgz "$EXE.multi" "$MEASURE" $ITERS $minutes $CORES $DIR networks/syeast[12]*/*.el || die "multi-pairwise failed"

# At this point $DIR has been archived, so un-archive it.
mkdir $DIR || die "hmm, '$DIR' should be gone"
cd $DIR/.. && tar zxf $DIR.tgz
cd $DIR
echo "Now check NC values: below are the number of times the multiple alignment contains k correctly matching nodes, k=2,3,4:"
echo "iter	NC2	NC3	NC4"
for m in `ls -rt *s/??/multiAlign.tsv`; do echo `dirname $m; for i in 2 3 4; do gawk '{delete K;for(i=1;i<=NF;i++)++K[$i];for(i in K)if(K[i]>='$i')print}' $m | wc -l; done`; done | sed 's/ /	/'
echo "And now the Multi-NC, or MNC, measure, of the final alignment"
echo 'k	number	MNC'
gawk '{delete K;for(i=1;i<=NF;i++)++K[$i];for(i in K)++nc[K[i]]}END{for(i=2;i<=NF;i++){for(j=i+1;j<=NF;j++)nc[i]+=nc[j];printf "%d\t%d\t%.3f\n",i,nc[i],nc[i]/NR}}' `ls -rt *s/??/multiAlign.tsv | tail -1` | tee $DIR/MNC.txt
echo "Check MNC are high enough: k=2,3,4 => 0.25,0.15,0.05, or sum >= $MINSUM"
gawk 'BEGIN{code=0}{k=$1;expect=(0.45-k/10);sum+=$3;if($3<expect)code=1}END{if(sum>'$MINSUM')code=0; exit(code)}' $DIR/MNC.txt || die "MNC failed"
