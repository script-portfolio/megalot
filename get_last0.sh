#!/bin/bash

set -e 
set -u

# APP=$0
# # http://stackoverflow.com/questions/1197690/how-can-i-derefence-symbolic-links-in-bash
# REAL_PATH=$(readlink -f "$APP" )
# HERE_PATH=$(dirname "${REAL_PATH}" )

EFFSCRIPT="$(readlink -f "${BASH_SOURCE[0]}")"
#MY_PATH="$(dirname "${EFFSCRIPT}")/"
APP="$(basename $EFFSCRIPT)"

TMPDIR="/tmp/$APP-$$-$RANDOM"
trap "[ -d \"${TMPDIR}\" ] && /bin/true echo rm -rf \"${TMPDIR}\" && rm -rf \"${TMPDIR}\" " EXIT
mkdir -p $TMPDIR

DUMP="$TMPDIR/dump"
EVALDATA="$TMPDIR/megalot0.env.data"
#EVALDATA=FileX

curl -s http://www.msl.ua/uk/megalot  >$DUMP


(
    cat $DUMP | grep -A 6 '<ul class="balls clearfix">' | sed -n -e 's/^\s\+<li class="\(red\|white\|yellow\)">\([0-9]\{1,2\}\)<\/li>$/B[${#B[@]}]=\2/p'  
    (( PIPESTATUS[0] || PIPESTATUS[1] || PIPESTATUS[2] )) && { touch $TMPDIR/err ;}

    cat $DUMP | \
    sed -n -e 's/^\s\+<b class="inline-block">\([0-9]\)<\/b>$/MK=\1/p' \
           -e 's/.*<h2>.*№\([0-9]\+[^0-9]\).*>від\s\+\([0-9]\+\)\s\+\(\S\+\)\s\+\(20[0-9]\{2\}\).*/N=\1\nDAY=\2\nMONTH=\3\nYEAR=\4/p'  
    ((PIPESTATUS[0] || PIPESTATUS[1] )) && touch $TMPDIR/err

) | tee $EVALDATA >/dev/null


[ -f "$TMPDIR/err" ] && exit 1

set +u
. $EVALDATA
set -u

MONTH=$(echo $MONTH | sed   -e 's/січня/01/'  -e 's/лютого/02/'    -e 's/березня/03/' \
                            -e 's/квітня/04/' -e 's/травня/05/'    -e 's/червня/06/'  \
                            -e 's/липня/07/'  -e 's/серпня/08/'    -e 's/вересня/09/' \
                            -e 's/жовтня/10/' -e 's/листопада/11/' -e 's/грудня/12/' )
printf -v DAY '%02d' $DAY

RESULT=$(echo "${B[*]}+$MK" | sed -e 's/\s/,/g' )
cat <<EOC
$N
$DAY.$MONTH.$YEAR
$RESULT
EOC

