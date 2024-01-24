include ../config.mk

FASTFIZ_LIB = ../libFastFiz.so
FASTFIZ_LIBS = -L.. -lFastFiz

perl:	Fiz.so Pool/Fiz.pm Pool/Rules.pm Rules.so

Pool:
	mkdir Pool

Fiz.so: FastFiz_perl_wrap.o my_wrappers.o $(FASTFIZ_LIB)
	$(CC) -shared $(LDFLAGS) FastFiz_perl_wrap.o my_wrappers.o $(LIBS) $(FASTFIZ_LIBS) -o $@
	
FastFiz_perl_wrap.cxx Pool/Fiz.pm: Pool ../FastFiz.h ../Noise.h FastFiz_perl.i
	swig -v -Wall -outdir Pool -c++ -perl FastFiz_perl.i

Rules.so: Rules_perl_wrap.o my_wrappers.o $(FASTFIZ_LIB)
	$(CC) -shared $(LDFLAGS) Rules_perl_wrap.o my_wrappers.o $(LIBS) $(FASTFIZ_LIBS) -o $@
	
Rules_perl_wrap.cxx Pool/Rules.pm: Pool ../Rules.h ../FastFiz.h Rules_perl.i
	swig -v -Wall -outdir Pool -c++ -perl Rules_perl.i

install:
	@echo "NOT IMPLEMENTED!"

clean:
	-rm *.o *.so Pool/Fiz.pm Pool/Rules.pm *.cxx *~ */*~ */*/*~

sinclude FastFiz_perl_wrap.d
sinclude Rules_perl_wrap.d

.PHONY: perl clean
