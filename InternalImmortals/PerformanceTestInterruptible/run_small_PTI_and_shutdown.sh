#!/bin/bash
echo "Using AZURE_STORAGE_CONN_STRING =" $AZURE_STORAGE_CONN_STRING
set -xeuo pipefail

# ------------------------------------------------------------------------------
# This script is meant to be used in automated testing.  The output is
# ugly (interleaved) because it creates concurrent child processes.
#
# It should exit cleanly after the test is complete.
#
# This is often invoked within Docker:
#   docker run -it --rm --env AZURE_STORAGE_CONN_STRING="$AZURE_STORAGE_CONN_STRING" ambrosia-perftest ./run_small_PTI_and_shutdown.sh
#
# ------------------------------------------------------------------------------

cd `dirname $0`
source ./default_var_settings.sh

INSTANCE_PREFIX=""
if [ $# -ne 0 ];
then INSTANCE_PREFIX="$1"
fi

CLIENTNAME=${INSTANCE_PREFIX}dockC
SERVERNAME=${INSTANCE_PREFIX}dockS

if ! which Ambrosia; then
    pushd ../../bin
    PATH=$PATH:`pwd`
    popd
fi

# UnsafeDeregisterInstance $CLIENTNAME || true
# UnsafeDeregisterInstance $SERVERNAME || true

Ambrosia RegisterInstance -i $CLIENTNAME --rp $PORT1 --sp $PORT2 -l "./ambrosia_logs/" 
Ambrosia RegisterInstance -i $SERVERNAME --rp $PORT3 --sp $PORT4 -l "./ambrosia_logs/"


COORDTAG=CoordServ AMBROSIA_INSTANCE_NAME=$CLIENTNAME AMBROSIA_IMMORTALCOORDINATOR_PORT=$CRAPORT1 \
  runAmbrosiaService.sh ./bin/Server --rp $PORT4 --sp $PORT3 -j $CLIENTNAME -s $SERVERNAME -n 1 -c & 
set +x
pid_server=$!
echo "Server launched as PID ${pid_server}.  Waiting a bit."
sleep 12
echo "Launching client now:"
set -x

COORDTAG=CoordCli AMBROSIA_INSTANCE_NAME=$CLIENTNAME AMBROSIA_IMMORTALCOORDINATOR_PORT=$CRAPORT2 \
  runAmbrosiaService.sh ./bin/Job --rp $PORT2 --sp $PORT1 -j $CLIENTNAME -s $SERVERNAME --mms 65536 -n 2 -c 

echo "Client finished, exiting."e
kill -9 $pid_server
wait
echo "Everything shut down.  All done."
