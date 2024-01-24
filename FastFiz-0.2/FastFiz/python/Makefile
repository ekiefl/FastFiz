include ../config.mk

FASTFIZ_LIB = ../libFastFiz.so
FASTFIZ_LIBS = -L.. -lFastFiz

python: _FastFiz.so FastFiz.py _Rules.so Rules.py

_FastFiz.so: FastFiz_python_wrap.o my_wrappers.o $(FASTFIZ_LIB)
	$(CC) -shared $(LDFLAGS) FastFiz_python_wrap.o my_wrappers.o $(FASTFIZ_LIBS) $(LIBS) -o $@
	
FastFiz_python_wrap.cxx FastFiz.py: FastFiz_python.i ../FastFiz.h
	swig -v -Wall -outdir . -c++ -python FastFiz_python.i

_Rules.so: Rules_python_wrap.o my_wrappers.o $(FASTFIZ_LIB)
	$(CC) -shared $(LDFLAGS) Rules_python_wrap.o my_wrappers.o $(FASTFIZ_LIBS) $(LIBS) -o $@
	
Rules_python_wrap.cxx Rules.py: Rules_python.i ../FastFiz.h ../Rules.h
	swig -v -Wall -outdir . -c++ -python Rules_python.i

install:
	@echo "NOT IMPLEMENTED!"

clean:
	-rm *.o *.so FastFiz.py Rules.py Rules.pyc FastFiz.pyc *.cxx *~ */*~ */*/*~

sinclude FastFiz_python_wrap.d
sinclude Rules_python_wrap.d

.PHONY: python clean
