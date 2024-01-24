#!/bin/sh
rm -rf releaseDIR
mkdir releaseDIR &&\
cd releaseDIR &&\
cvs -d`cat ../CVS/Root` export -DNOW poolfiz/newserver &&\
mv poolfiz/newserver FastFiz-$1 &&\
rm FastFiz-$1/client/*.conf &&\
rm -rf FastFiz-$1/CueCard &&\
cp -a FastFiz-$1/release/* FastFiz-$1 &&\
ln -s ../../../www/gwt/pool FastFiz-$1/gwt-src/Pool/war/pool && \
#cp -a ../www/gwt FastFiz-$1/www/ &&\
tar -czvf ../FastFiz-$1.tar.gz FastFiz-$1/ &&\
cd .. &&\
(rm -rf releaseDIR; rm -rf upload ; mkdir upload) && \
cd upload && \
ln -s ../www/api.html ../www/database.html ../www/database.png ../www/www-doc.html ../FastFiz-$1.tar.gz . && \
ln -s ../FastFiz/doc/html FastFiz && \
cd ..
