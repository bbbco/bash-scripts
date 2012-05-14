#!/bin/bash

#########################################################################################
#                                [TITLE]:												#
#               Expects:																#
#               Purpose:																#
#########################################################################################
#       Changelog:                                                                      #
#                                                                                       #
#########################################################################################

#Begin Script
STARTDATE=$(date)

#Dependencies
#SVN=$(which svn)
#SSH=$(which ssh)
#ANT=$(which ant)
#JAVA=$(which java)

#Standard Variables
DATE=$(date)
ME=${0##*/}
BASEDIR=$(cd $(dirname $0) && pwd)
OWNER=$(stat -c %U $0)
CURRENT_USER=$(id | sed 's/uid=[0-9][0-9]*(\([^)]*\)).*/\1/')
LOCKFILE="/tmp/.${ME}.lck"
TEMPOUTPUT="/tmp/.${ME}.tmp"
TEMPLOG="/tmp/.${ME}.log"
FAILLOG="${BASEDIR}/${ME}.err"
MAINLOG="${BASEDIR}/${ME}.log"

#################################################

#Expected Variables
SERVER=""
DEBUG="0"
HELPS="\

Usage: $ME [ parameters ]

[description] 

Operation modes:
  -h		print this help, then exit
  -v		print version number, then exit
  -d		run in debug mode

Dependencies:
  XXX:		${X}

Report bugs to <[email]>.
---------------------------------------------------------------
Parameters and Flags tried: $*"
VERSION="$ME v0.x"

#################################################

#Begining Function
function begin()
{

  #Lock process, trap and quit nicely
  trap ' quitting $? ' INT TERM EXIT
  touch ${LOCKFILE}

  #Watch the log in the terminal
  touch ${TEMPOUTPUT}
  tail -f ${TEMPOUTPUT} 2>/dev/null &
  TPID=$!

  #Make sure we are in the base directory (in case the script is executed from outside it's parent dir)
  cd ${BASEDIR}



  exit

} #END begin FUNCTION


#Function to log script activities
function log()
{

  DATED=`date +"%F %T.%N" | cut -b1-23`
  (echo -e "[ ${DATED} ] $* \n" 2>&1) | tee -a ${TEMPLOG}

}

#Function to log output and status of commands
function elog()
{

  DESCRIPTION="${1}"

  log "\n \
    \t\t Command => ${2}\n \
    \t\t Description => ${DESCRIPTION} \n \
    -----------------------------------------------------------------------"

  #Show output in terminal in real-time (via tail -f in begin function) while saving to temp file and get exit code status
  ${2} > ${TEMPOUTPUT} 2>&1
  STATUS=${PIPESTATUS[0]}

  #Write any output to log file
  cat ${TEMPOUTPUT} >> ${TEMPLOG}

  #If the output's exit status is not 0, we have a failure
  if [ "${STATUS}" -ne 0 ]; then
     log "Result => FAILED - Exit Code: ${STATUS}\n \
    =======================================================================\n"

    #Output to separate fail file
    echo -e "FAILED: \n \
    \t\t Command => ${2}\n \
    \t\t Description => ${DESCRIPTION} \n \
    \t\t Exit Code => ${STATUS}\n \
    =======================================================================\n" >> ${FAILLOG}
    cat ${TEMPOUTPUT} >> ${FAILLOG}
    echo -e "\n \
    =======================================================================\n" >> ${FAILLOG}

  #Must have been a success!
  else
    log "Result => SUCCEEDED - Exit Code: ${STATUS}\n \
    =======================================================================\n"
  fi

}
#Kills the sub process quietly
function killsub()
{

    kill -9 ${1} 2>/dev/null
    wait ${1} 2>/dev/null

}

#Function to clean up and quit out of script
function quitting()
{
  EXITCODE=$?

  log "Exiting with status code: ${EXITCODE}"

  #Kill tail process
  killsub ${TPID}

  #If we had bad failures
  if [ -e "${FAILLOG}" ]; then

      echo -e "\n++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\nFAILED COMMANDS\n" >> ${MAINLOG}

      cat ${FAILLOG} >> ${MAINLLOG}
      echo -e "\n++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\n\n" >> ${MAINLLOG}

  fi

  #Cat the log 
  cat ${TEMPLOG} >> ${MAINLOG}

  mv ${TEMPLOG} /tmp/${ME}.log
  rm ${LOCKFILE} ${TEMPLOG} ${TEMPOUTPUT} ${FAILLOG}

  trap - INT TERM EXIT
  exit ${EXITCODE}

}


#################################################

#Check parameters
if [ "$#" -gt 0 ]; then

  #Save actual command
  ACTUALCOMMAND="$*"

  # Parse command line arguments
  while getopts "vhds:" opt; do
    case "$opt" in
      v) echo "$VERSION"; exit;;
      h) echo "$HELPS"; exit;;
      d) DEBUG="1";;
      s) SERVER="$OPTARG";;
      *) . color red "Invalid arguments: ${*}"; echo "$HELPS"; exit;;
    esac
  done
  shift $(($OPTIND - 1))

  #Debug via set -x
  if [ "$DEBUG" == 1 ]; then

    set -x

  fi

  #Gotta make the script smart about parameter usage...
  if [ -e "${LOCK}" ]; then

    echo "${ME} is currently locked, and most likely running."
    echo "If you need to run this script, please be sure the process is not running and manually remove ${LOCK}"
    exit 1

  fi
  if [ "${OWNER}" != "${CURRENT_USER}" ]; then

    echo "${ME} must be run by ${OWNER}\!"
    exit 1

  fi

  if [ -z "${SVN}" ] || [ -z "${ANT}" ] || [ -z "${JAVA}" ] || [ -z "${SSH}" ] || [ ! -e "${SENDEMAIL}" ]; then

    echo "One or more dependencies do not exist!"
    echo "Please check to ensure you have SVN, ANT, JAVA and SSH packages available from your PATH variable,"
    echo "and the send_email.sh script living in the same directory as ${ME}."
    exit 1

  fi
  if [ "$(${SSH} -q -q -o BatchMode=yes -o ConnectTimeout=10 ${SVNSERVER%%/*} echo up 2>&1)" != "up" ]; then

    echo "Cannot connect to SVN server!"
    echo "Please ensure that the SVNSERVER variable is defined correctly, and the local server's Shared SSH Keys are installed correctly!"
    exit 1

  fi

  if [ "$(${SVN} info svn+ssh://${SVNSERVER}/${BRANCH} 2>&1 | grep valid >/dev/null; echo $?)" -eq 0 ]; then

    echo "Branch \"${BRANCH}\" specified is not a valid SVN branch:"
    echo "${SVN} info svn+ssh://${SVNSERVER}/${BRANCH}"
    ${SVN} info svn+ssh://${SVNSERVER}/${BRANCH}
    exit 1

  fi

  if [ "${SERVER}" == "" ]; then

    echo "Flags and argument for -s are required in order to run this script." 
    echo "$HELPS"
    exit 1

  else

    begin

  fi #If SERVER == ""

else

  echo "No Arguments specified"
  echo "$HELPS"
  exit

fi #Fin if $#

########################################################
