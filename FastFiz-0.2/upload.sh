#!/bin/sh
cd upload &&\
tar -cvhf - . | ssh epsalon@cardinal.stanford.edu 'cd /afs/ir/group/billiards/WWW; tar -xvf -' && \
cd ..

