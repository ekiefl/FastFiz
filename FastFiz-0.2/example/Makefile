include config.mk

SRC=example.cpp
BIN = ./example

default: all

all: $(BIN)

install: all

$(FASTFIZ_LIB):
	make -C ../FastFiz

$(BIN): $(SRC:.cpp=.o) $(FASTFIZ_LIB)
	@echo "** Linking '$@' **"
	$(CC) -o $@ $^ $(LDFLAGS) $(LIBS)

depend:	clean
	make depfiles

depfiles:	$(SRC:.cpp=.d)
	@echo Done making depends

clean:
	-rm *~ */*~ */*/*~ *.o *.so *.d $(BIN)

sinclude $(SRC:.cpp=.d) 

.PHONY: clean all install depend depfiles

# DO NOT DELETE

