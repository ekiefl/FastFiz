include config.mk

LIBSRC = $(wildcard *.cpp)
LIB = AI.a
LIB_SHARED = AI.so

default: all

all: $(LIB) $(LIB_SHARED)

libobj: $(LIBSRC:.cpp=.o)

install: all

$(LIB_SHARED): $(LIBSRC:.cpp=.o) $(FASTFIZ_LIB) $(CONFIG_LIB)
	@echo "** Linking '$@' **"
	$(CC) --shared -o $@ $^ $(LDFLAGS) $(LIBS)

$(LIB): $(LIBSRC:.cpp=.o)
	ar rv $@ $?
	ranlib $@

depend:	clean
	make depfiles

depfiles:	$(LIBSRC:.cpp=.d)
	@echo Done making depends

clean:
	-rm *~ */*~ */*/*~ *.o *.so *.d $(LIB) $(LIB_SHARED)

sinclude $(LIBSRC:.cpp=.d) 

.PHONY: clean all install depend depfiles

# DO NOT DELETE

