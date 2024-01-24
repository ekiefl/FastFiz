#!/bin/sh
echo ${HOST} `uptime` >> exp-host.list
cd /afs/cs.stanford.edu/u/cja/poolfiz/newserver/client
./client -c experiment.conf -m f -f 2 -t v &> ${PBS_JOBID}.out
