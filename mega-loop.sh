#!/bin/bash

set -u
DEBUG=
APP=$0
# http://stackoverflow.com/questions/1197690/how-can-i-derefence-symbolic-links-in-bash
REAL_PATH=$(readlink -f "$APP")
HERE_PATH=$(dirname "${REAL_PATH}")
LOG_PATH="$HERE_PATH"
MAX_LOG_CNT=4
NOTHING_PERIOD=10
export MEGALOT_PID= # for one more invoke monitoring

ALREADY_RUNNING_ALARM=$((10))

MINPERIOD=              # without check
MINPERIOD=$((50*60+10))    # minimal period between curl http:..
#MINPERIOD=4

SUCCESS_TOO_FRESH=$((60*60*23))
#SUCCESS_TOO_FRESH=2



DIFFBINDING=60 # diff ... | head -n 60
MIN_SIZE=28 # size of get_last0.sh output
MAX_SIZE=58 # size of get_last0.sh output

LOGFILENAME='log.file'
LOGFILE="$LOG_PATH/${LOGFILENAME}"
OLOGFILENAME="outer.log.file" ## see etc/..crontab
OLOGFILE="${LOG_PATH}/${OLOGFILENAME}" 

RAW_PATH="$HERE_PATH/Raw"
mkdir -p $RAW_PATH/

TOTAL_CNT_FILE="$RAW_PATH/total.cnt"
SUCCESS_CNT_FILE="$RAW_PATH/success.cnt"

STATUS=
function counters {
    #echo "counters: TOTAL_CNT=$TOTAL_CNT SUCCESS_CNT=$SUCCESS_CNT " | eval $OUT
    #((TOTAL_CNT))   && 
    echo $((++TOTAL_CNT)) > "${TOTAL_CNT_FILE}"
    #((SUCCESS_CNT)) && 
    [ "${STATUS} X" == 'success X' ]  && \
    echo $((++SUCCESS_CNT)) > "${SUCCESS_CNT_FILE}"
}

function mobile_inform {
    #sed -e :a -e '$!N; s/\n/\\n/; ta' 
#    echo -e "${DESIRED_DATA}" | sed -e ':a;N;$!ba;s/\n/\&#10;/g'  | eval $OUT
# | curl -s --data @- -X POST http://localhost:3009/send/ | eval $OUT
    for MOBILE in ${MOBILES[@]:0} ; do
        #echo -e "${DESIRED_DATA}" | sed -e ':a;N;$!ba;s/\n/\&#10;/g'  | \
        echo -e "${DESIRED_DATA}" | pbsms --text - --phone ${MOBILE} | eval $OUT
        echo | eval $OUT 
        sleep 2
    done
}

ROTATE=
function logrotate_inform {
    ##ls -lt $OLOGFILE
    #echo "${OLOGFILE}"

    OLOGSIZE=
    [ -f "${OLOGFILE}" ] && {
        OLOGSIZE=$(stat -c %s $OLOGFILE)
        OLOGFILE_WC=$(cat "${OLOGFILE}" | wc -l )
    }

    [ "${STATUS}" != 'already_running' ] && ((OLOGSIZE && 1 )) && {

        HOWOLD=$(( NOW-$(stat -c %Y "${OLOGFILE}" ) ))
        echo | eval $OUT
        echo "Not null size [${OLOGSIZE} bytes, ${OLOGFILE_WC} lines] '${OLOGFILE}' detected." | eval $OUT
        echo "Lines: $OLOGFILE_WC. Age: $(time-text $HOWOLD ). Will be rotate and sent." | eval $OUT
        #echo "Will be sent as email attachment." | eval $OUT
        echo | eval $OUT

        ## create STATUS ( not null outer log )
        [ -z "${STATUS}" ] && STATUS='not_null_outer_log'

        #echo FIND: find "${LOG_PATH}" -name [0-9]*\.${OLOGFILENAME} -type f -printf '%f\n' 
        find "${LOG_PATH}" -name [0-9]\*\.${OLOGFILENAME} -type f -printf '%f\n' | sort -t '.' -k1 -nr | while read CF; do
#echo "CF=$CF"
            NUM="${CF%%\.*}"
            ((NUM+1>MAX_LOG_CNT)) && { 
                LANG=C rm -v "$LOG_PATH/$CF" | eval $OUT
                continue
            }
            printf -v NEWCF "%d.$OLOGFILENAME" $((++NUM))
            mv -v "${LOG_PATH}/$CF" "${LOG_PATH}/${NEWCF}"  | eval $OUT

        done 
        [ -f "${OLOGFILE}" ] && {
            cp -av "${OLOGFILE}" "$LOG_PATH/0.${OLOGFILENAME}" | eval $OUT
            #cp /dev/null $OLOGFILE
        }
    
    }

    #echo
    CURLOG="${LOGFILE}"
    ((ROTATE)) && {
        echo "logrotate. Rotate=$ROTATE" | eval $OUT
        find "${LOG_PATH}" -name [0-9]*\.${LOGFILENAME} -type f -printf '%f\n' | sort -t '.' -k1 -nr | while read CF; do
            #echo CF: $CF
            NUM="${CF%%\.*}"
            ((NUM+1>MAX_LOG_CNT)) && { 
                LANG=C rm -v "$LOG_PATH/$CF" | eval $OUT
                continue
            }
            printf -v NEWCF "%d.$LOGFILENAME" $((++NUM))
            #echo $NUM $NEWCF
            #echo mv -v "${LOG_PATH}/$CF" "${LOG_PATH}/${NEWCF}" 
            mv -v "${LOG_PATH}/$CF" "${LOG_PATH}/${NEWCF}"  | eval $OUT
        done

        [ -f "${LOGFILE}" ] && {
            cp -av  $LOGFILE "$LOG_PATH/0.${LOGFILENAME}" | eval $OUT
            CURLOG="$LOG_PATH/0.${LOGFILENAME}"
            cp /dev/null $LOGFILE
        }
    }

    #echo "St: $STATUS"

    SUBJECT=
    ATTACHMENTS=
    case "$STATUS" in
        wrong_lwp_code)
            SUBJECT="Error. LWP code: $LWPCODE"
            ;;

        already_running)
            ((ALREADY_RUN_ELAPSED>ALREADY_RUNNING_ALARM)) && {
                SUBJECT="Already Running status (too long): $ALREADY_RUN_TXT"
                ATTACHMENTS=(
                    $CURLOG
                )
            }
            ;;

        invalid_size)
            SUBJECT="Invalid size '$SIZECUR' bytes. Min/Max: $MIN_SIZE/$MAX_SIZE."
            ATTACHMENTS=(
               $DIFF_FILE 
            )

            ;;

        success)
            SUBJECT="Success: $(echo -e "$DESIRED_DATA" |sed -e :a -e '$!N; s/\n/  /; ta' )"
            echo | eval $OUT
            echo "ls -lt ${RAW_PATH}:" | eval $OUT
            ls -lt "$RAW_PATH" | cat -n | eval $OUT
            echo | eval $OUT

            mobile_inform  
            ATTACHMENTS=(
               $DIFF_FILE 
               $CURLOG
            )
            ;;

        first_run)
            ;;

        not_null_outer_log)
#            SUBJECT="Not null outer log. Lines: $OLOGFILE_WC. Modified: ..."
#            ATTACHMENTS=(
#                $CURLOG 
#            )
            ;;

        nothing)
            ((NOTHING_PERIOD_ALARM)) && {
                SUBJECT="Too much [${NOTHING_PERIOD}/${TRIES}] idle invokes."
                ATTACHMENTS=(
                   $CURLOG 
                )
            } 
            ;;
        success_to_fresh)
            ;;
        *)
            echo "Undefined status: $STATUS" | eval $OUT
            ;;
    esac

    #echo "SUBJECT: $SUBJECT"
    
    ((OLOGSIZE)) &&  [ -z "${SUBJECT}" ] && \
    SUBJECT="Not null size [$OLOGSIZE bytes/$OLOGFILE_WC lines] '$OLOGFILE'."

    [ -n "${SUBJECT}" ] && {

        ATTACHMENTS_CNT=
        [ -n "$ATTACHMENTS" ] && {
            ATTACHMENTS_CNT=${#ATTACHMENTS[@]}
            ATTACHMENTS=$( for i in "${ATTACHMENTS[@]}"; do echo -n "--attach $i " ; done )
            
        }

        ((OLOGSIZE)) && {
            ((++ATTACHMENTS_CNT))
            ATTACHMENTS="${ATTACHMENTS}--attach ${OLOGFILE}"
        }

        SUBJECT="[$SUCCESS_CNT/$TOTAL_CNT:${ATTACHMENTS_CNT}] $SUBJECT"

            #--verbose  \
        #echo  \
        smtp-cli  \
            --ipv4 \
            --server=smtp.yandex.ru  \
            --port=465 --ssl  \
            --user=$SMTP_USER --password=$SMTP_PASS  \
            ${BCC:+ $BCC}  \
            --charset=utf8  \
            --from "Megalot Notifier <${SMTP_USER}>"  \
            --subject "$SUBJECT" \
            ${ATTACHMENTS:+ $ATTACHMENTS} \
            --body-plain $STATUSFILE \
            --to "$RECEIVER"   | eval $OUT
#sleep 10
        ((OLOGSIZE)) && cp -v /dev/null "${OLOGFILE}" | eval $OUT
    }
    #echo TRIES $TRIES  | eval $OUT
    #echo TRIES MOD $((TRIES%10))  | eval $OUT
#
#    echo CODE $?  | eval $OUT
#    echo STATUS $STATUS  | eval $OUT
 
}

function rmlock {
    echo 'rmlock' | eval $OUT
    [ -f "${LOCKFILE}" ] && rm "${LOCKFILE}"
}

LOCKFILE="$HERE_PATH/lockfile.megalot"
#trap "[ -f \"${LOCKFILE}\" ] && rm \"${LOCKFILE}\" " EXIT SIGTERM
trap " counters ; logrotate_inform ; rmlock" EXIT SIGTERM

STATUSFILE="$HERE_PATH/status.file"
FILENAMETAG='megalot'
FILENAMETAG0='current'

NOW=$(date +%s)

RECEIVER='vladyslav.gula@gmail.com'
SMTP_USER='s***r.v****ed@ya.ru'
SMTP_PASS=$(proj-pass $SMTP_USER)

MOBILES=(
    '3806****0654'
    '38095***0001'
)

MANUAL_NOHUP=${1:-} # if set - nohup mode
#echo DEBUG=$DEBUG

if [ -t 1 -a -z "${MANUAL_NOHUP}" ]; then
    #echo 'term'
    MODE='term'
    #STDOUT='/dev/fd/1'
    #STDERR='/dev/fd/2'

    OUT='cat'
else
    #echo 'nohup'
    MODE='nohup'
    #STDOUT="${HERE_PATH}/stdout.log"
    #STDERR="${HERE_PATH}/stderr.log"
    [ -f "${STATUSFILE}" ] && rm "${STATUSFILE}"
    OUT="perl -MPOSIX -ne ' print strftime (\"%F %T \",  localtime \$^T), \$ENV{MEGALOT_PID}.\$_ ' | tee -a $STATUSFILE >> $LOGFILE 2>&1 "
    #mkdir -p $(dirname $STDOUT)
fi

((1)) && {
    TOTAL_CNT=0
    [ -f "${TOTAL_CNT_FILE}" ] && TOTAL_CNT=$(cat $TOTAL_CNT_FILE)
    SUCCESS_CNT=0
    [ -f "${SUCCESS_CNT_FILE}" ] && SUCCESS_CNT=$(cat $SUCCESS_CNT_FILE)
}


((1)) && {

    if [ -f "${LOCKFILE}" ]; then
        #trap " counters ; logrotate_inform " EXIT SIGTERM
        #trap " logrotate_inform " EXIT SIGTERM
        trap " logrotate_inform " EXIT SIGTERM
        ALREADY_RUN_ELAPSED="$(( NOW-$(stat -c %Y ${LOCKFILE}) ))"
        ALREADY_RUN_TXT="$(time-text $((ALREADY_RUN_ELAPSED)) )"
        export MEGALOT_PID="[$$] "
        echo  | eval "$OUT"
        echo "Already running as process PID=$(cat ${LOCKFILE})." | eval "$OUT"
        echo "Elapsed: ${ALREADY_RUN_TXT}." | eval "$OUT"
        echo "JFI: Elapsed alarm set as: $(time-text ${ALREADY_RUNNING_ALARM})." | eval "$OUT"
        STATUS='already_running'
        exit 0
    else
        echo $$ >  "${LOCKFILE}"
    fi
}
function stamp_suffix {
    local FILE=$1
    SUFFIX="$(stat -c %y "${FILE}"  | cut -b -19 | sed -e 's/\s/_/')"
    echo "$SUFFIX"
}

function get_and_touch {
    # create data from (curl)
    local PREFIX="${1:-$FILENAMETAG}"

    FILE="$RAW_PATH/$PREFIX.data"
    if ((DEBUG)); then
        DATA_LINE='11,21,21,41,21,21+10'
        #(( (RANDOM%50) == 38 )) && DATA_LINE='1,2,3,4,5,6+0'
        cat <<EOC >$FILE
0086
$(date +%F)
${DATA_LINE}
EOC
        CODE=0
        #(( (RANDOM%50) == 5 )) && CODE=1

    else 
        bash $HERE_PATH/get_last0.sh > $FILE
        CODE=$?
        sleep 2
    fi
    SUFFIX=$(stamp_suffix $FILE)
    NAME="$RAW_PATH/$PREFIX.${SUFFIX}"
    mv "$RAW_PATH/$PREFIX.data" "$NAME"
    echo "$NAME"
    return $CODE 
}
###############################################################################
### Body ...
DATA_FILE=$(ls -dt1 ${RAW_PATH}/${FILENAMETAG}* 2>/dev/null |  sed -n -e "s/.*\(${FILENAMETAG}\.20[0-9]\{2\}-[0-9]\{2\}-[0-9]\{2\}_[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\$\)/\1/p" | head -1 )
DATA_FILE="$RAW_PATH/$DATA_FILE"
#echo "DataFile: $DATA_FILE"

echo | eval $OUT
echo "******************* $APP. Started. [$SUCCESS_CNT/$TOTAL_CNT]" | eval $OUT
echo "*** PID $$. Lockfile created." | eval $OUT

if [ ! -f "$DATA_FILE" ]; then
  echo 'Data file absent. Create... ' | eval "${OUT}"
  DATA_FILE="$(get_and_touch)"
  LWPCODE=$?
  echo "Created: $DATA_FILE. Return code: $LWPCODE" | eval $OUT
  echo | eval "${OUT}"
  echo "Data:" | eval $OUT
  cat -n "$DATA_FILE" | eval $OUT
  echo 'Start smpt session to send email (to setup)' | eval "${OUT}"
  echo | eval "${OUT}"
  #init_email $DATA_FILE | eval "$OUT"
  #echo | eval "${OUT}"
  echo 'Exiting...' | eval "${OUT}"
  STATUS='first_run'
  exit 0
fi

#echo 'MegalotData: ' $DATA_FILE

#DATA="$(cat ${DATA_FILE} | sed -e :a -e '$!N; s/\n/\n/; ta' | cut -b -80 )"
#DATA="$(cat ${DATA_FILE} | sed -e :a -e '$!N; s/\n/\n/; ta' )  " #| cut -b -80 )"
#DATA=$(cat ${DATA_FILE} | sed -e :a -e '$!N; s/\n/\\n/; ta' )

echo "Datafile \"$DATA_FILE\" encountered." | eval "${OUT}"
cat -n "${DATA_FILE}" | eval "${OUT}"
echo | eval $OUT

TIMESTAMP=$(stat -c %Y $DATA_FILE )

if [ "${MODE}X" == 'nohupX' ]; then

    #echo DATA: $(date -d @$TIMESTAMP +'%F %T' ) | eval "$OUT"
    #((${#DATA_FILE}==27)) && echo FF: ${#DATA_FILE}
    #echo "DIFF $NOW - $TIMESTAMP VAL= $MINPERIOD"

    SUCCESS_FILE_STAMP=0
    [ -f "${SUCCESS_CNT_FILE}" ] && \
        SUCCESS_FILE_STAMP=$( stat -c %Y $SUCCESS_CNT_FILE )

    SUCCESS_DIFF="$SUCCESS_TOO_FRESH"
    ((SUCCESS_FILE_STAMP)) && {
        echo 'TimeStamp checking section:' | eval $OUT
        SUCCESS_DIFF=$((NOW - SUCCESS_FILE_STAMP))
        echo -e "\tLast success: $(time-text $SUCCESS_DIFF). (ago)." | eval $OUT
        echo -e "\t'too fresh' delay declared as: $(time-text ${SUCCESS_TOO_FRESH:-0})" | eval $OUT
    }
    echo | eval $OUT

    # Был же успех! Только что ( совсем недавно ). Жди.. Поболе..
    if (( SUCCESS_DIFF < SUCCESS_TOO_FRESH )); then
        echo 'Data file is too fresh'  | eval $OUT
        STATUS=success_to_fresh

    # недавно уже получали значения. Уж больно часто
    elif (( MINPERIOD && NOW-TIMESTAMP < MINPERIOD)); then
        echo "Data is considered to be fresh for another $(time-text $(( MINPERIOD - NOW + TIMESTAMP )) )"  | eval "$OUT"
        exit 0
    #  данные можно было обновить уже ..столько-то времени.. тому назад
    #elif (( MINPERIOD )); then
    else
        echo "Data is have been ready for update: $(time-text $((  NOW-TIMESTAMP-MINPERIOD  )) ) ago [delay is $(time-text ${MINPERIOD})] " | eval "$OUT"
        TRIES="$(ls -1 $RAW_PATH/$FILENAMETAG0* 2>/dev/null| wc -l )"
        #echo Tr: $TRIES
        if ((TRIES)); then
            PART1="Tries: $(ls -1 $RAW_PATH/$FILENAMETAG0* | wc -l )"
            LAST="$(ls -t $RAW_PATH/$FILENAMETAG0* | head -1 | xargs stat -c %Y )"
            FIRST="$(ls -t $RAW_PATH/$FILENAMETAG0* | tail -1 | xargs stat -c %Y )"
            #echo    "${PART1}. Performed (ago) last: $(time-text $(( NOW - LAST )) ), first: $(time-text $((NOW-FIRST)) )." | eval $OUT
            MSG="${PART1}. Performed (ago) last: $(time-text $(( NOW - LAST )) ), first: $(time-text $((NOW-FIRST)) )."
            ((TRIES==1)) && \
            MSG="${PART1}. Last performed: $(time-text $(( NOW - LAST )) ) ago."
            echo "${MSG}" | eval $OUT


        else
            echo 'No one attempt to update Data' | eval $OUT
        fi
        echo | eval $OUT


        echo    "Start to retreive..." | eval "$OUT"

        CURDATA=$( get_and_touch "$FILENAMETAG0" )
        LWPCODE=$?
        (($LWPCODE)) && {
            echo "Not null [$LWPCODE] status code. Send control email and exiting." | eval $OUT
            echo | eval $OUT
            STATUS='wrong_lwp_code'
            exit 1
        }

        SIZECUR=$(stat -c %s $CURDATA)
        SIZEOLD=$(stat -c %s $DATA_FILE)

        VALID_SIZE=1
        (( SIZECUR < MIN_SIZE || SIZECUR > MAX_SIZE )) && VALID_SIZE=

        PART1=$(echo "I got '$SIZECUR' bytes. ")
        PART2=
        ((!VALID_SIZE)) && PART2="*** The size is invalid! "

        PART3= #'Old size the same. '
        ((SIZEOLD!=SIZECUR)) && PART3="Old size is '$SIZEOLD' bytes. "

        DIFF_FILE=$RAW_PATH/diff_file
        diff "${DATA_FILE}" "${CURDATA}" > ${DIFF_FILE}
        DIFFCODE=$?
        ((!DIFFCODE)) && ((!$(stat -c %s ${DIFF_FILE}))) && rm "${DIFF_FILE}" | eval $OUT

        PART4="The datasets is equil."
        ((DIFFCODE)) && PART4="The datasets is not equil. '$DIFF_FILE' created. "

        MESS="${PART1}${PART2}${PART3}${PART4}"
        echo "$MESS" | eval $OUT

        ((DIFFCODE)) && {
            echo "Diff [head ${DIFFBINDING} lines]: " | eval $OUT
            cat -n "$DIFF_FILE" | head -${DIFFBINDING} | eval $OUT
        }

        ((!VALID_SIZE)) && {
            VAR="$(cat $CURDATA | sed -e :a -e '$!N; s/\n/\\n/; ta' )"
            echo "The file is '$(basename $CURDATA)'. First 80 symbols: '${VAR:0:80}'" | eval $OUT
            echo "Start to email ... Email... (todo)" | eval $OUT
            STATUS='invalid_size'
            exit 1
        }

        ## Need save and inform
        if ((DIFFCODE)) && ((VALID_SIZE)); then
            SUFFIX="$(stamp_suffix $CURDATA)" 
            #echo "cur sufix: $SUFFIX" | eval $OUT
            LANG=C rm -v $DATA_FILE  | eval $OUT
            DESIRED_DATA="$(cat "${CURDATA}" )"
            LANG=C mv -v $CURDATA "${RAW_PATH}/megalot.$SUFFIX" | eval $OUT
            LANG=C rm -v $RAW_PATH/${FILENAMETAG0}* 2>/dev/null | eval $OUT
            STATUS=success
            ROTATE=1
        else
            NOTHING_PERIOD_ALARM=$((!(TRIES % NOTHING_PERIOD) && TRIES ))
            TEXT=
            ((NOTHING_PERIOD_ALARM)) && TEXT=' Notification will be send.'
            echo -e "\t\t*** Nothing to do. We are waiting significant updates." | eval $OUT
            echo -e "\t\t*** Period/Counter: ${NOTHING_PERIOD}/${TRIES}.${TEXT}" | eval $OUT
            #((NOTHING_PERIOD_ALARM)) && 
            STATUS=nothing
        fi
    fi

    #PREV_DATA=$(cat $DATA_FILE)
    #DATA=$(bash $HERE_PATH/get_last0.sh)
    
else

    echo mode=$MODE

fi

