include config.mk

SRC=Agent.cpp client.cpp
BIN = $(TARGET_DIR)/client

default: all

all: $(BIN)

libobj: $(LIBSRC:.cpp=.o)

install: all

$(AI_LIB):
	make -C $(AI_DIR)
	
$(FASTFIZ_LIB):
	make -C ../FastFiz

$(BIN): $(SRC:.cpp=.o) $(FASTFIZ_LIB) $(CONFIG_LIB) $(AI_LIB)
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

