include config.mk

FASTFIZ_LIB = FastFiz.a
FASTFIZ_SHARED = libFastFiz.so
FASTFIZ_INSTALLED = /usr/local/lib/$(FASTFIZ_SHARED)
LIBSRC = FastFiz.cpp Rules.cpp Noise.cpp Stopwatch.cpp AIBase.cpp LogFile.cpp
TESTSRC=FastFizTest.cpp
TESTBIN = $(TARGET_DIR)/FFTest

default: all

all: $(TESTBIN) $(FASTFIZ_LIB) $(FASTFIZ_SHARED) perl python doc

libobj: $(LIBSRC:.cpp=.o)

install: all $(FASTFIZ_INSTALLED)
	$(MAKE) -C perl install
	$(MAKE) -C python install

$(FASTFIZ_SHARED): $(LIBSRC:.cpp=.o) $(CONFIG_LIB)
	gcc -shared $^ -o $@
	strip $@

$(FASTFIZ_LIB): $(LIBSRC:.cpp=.o)
	ar rv $@ $?
	ranlib $@

$(TESTBIN): $(TESTSRC:.cpp=.o) $(FASTFIZ_LIB)
	@echo "** Linking '$@' **"
	$(CC) -o $@ $^ $(LDFLAGS) $(LIBS)

doc: *.h *.cpp *.cc
	$(MAKE) -C doc

depend:	clean
	$(MAKE) depfiles

depfiles:	$(SRC:.cpp=.d)
	@echo Done making depends

perl: $(FASTFIZ_SHARED)
	$(MAKE) -C perl

python: $(FASTFIZ_SHARED)
	$(MAKE) -C python

clean:
	$(MAKE) -C perl clean
	$(MAKE) -C python clean
	$(MAKE) -C doc clean
	-rm *~ */*~ */*/*~ *.o *.so *.d $(TESTBIN)

$(FASTFIZ_INSTALLED): $(FASTFIZ_SHARED)
	install $(FASTFIZ_SHARED) $(FASTFIZ_INSTALLED)
	ldconfig

$(CONFIG_TEST): $(CONFIG_TGZ)
	tar -xzvf $< && mv libconfig-1.3 $(CONFIG_PATH)
	touch $(CONFIG_TEST)

$(CONFIG_LIB): $(CONFIG_TEST)
	cd $(CONFIG_PATH) && ./configure --with-pic && $(MAKE)


bundle: $(BUNDLE)

$(BUNDLE): $(BUNDLE_FILES) $(addprefix ../,$(EXTRA_FILES))
	cd .. && tar -czhvf $(MYDIR)/$(BUNDLE) $(addprefix $(MYDIR),$(BUNDLE_FILES)) $(EXTRA_FILES)

force_upload:
	rm $(DEPLOYED_FILE)
	$(MAKE) upload

upload: $(DEPLOYED_FILE)
	#perl restart-servers.pl
	touch upload

$(DEPLOYED_FILE): $(BUNDLE)
	cp $(BUNDLE) $(DEPLOYED_FILE)

sinclude $(LIBSRC:.cpp=.d) 

.PHONY: clean perl python all install upload force_upload bundle depend depfiles doc

# DO NOT DELETE

