CONFIG_TGZ = ../libconfig-1.3.tar.gz
CONFIG_PATH = ../libconfig-1.3
CONFIG_TEST = $(CONFIG_PATH)/configure
CONFIG_INC = -I$(CONFIG_PATH)
CONFIG_LIB = $(CONFIG_PATH)/.libs/libconfig++.a
GSL_INCLUDES = $(shell gsl-config --cflags)
GSL_LIBS = $(shell gsl-config --libs)
PERL_PATH = $(strip $(shell perl -V::archlibexp:))
PERL_CORE = $(PERL_PATH)/CORE
CC = g++
OPTIMIZE = -g -O3 --param inline-unit-growth=50
INCLUDES = -I. -Ilib $(CONFIG_INC)  $(shell python-config --includes) -I$(PERL_CORE)
TARGET_DIR = .

CFLAGS= $(OPTIMIZE) -Winline -Wall -Wno-deprecated $(INCLUDES) -fPIC
CXXFLAGS = $(OPTIMIZE) $(INCLUDES) -I.. -fPIC
#CFLAGS= $(OPTIMIZE) -DNDEBUG -Wall -Wno-deprecated $(INCLUDES)
LDFLAGS = $(INCLUDES) -O1 -finline-functions -ffast-math -Wl,-rpath,.:..:../FastFiz/
LIBS = -lc $(GSL_LIBS) $(shell python-config --libs)

%.o:	%.cxx 
	@echo "** Compiling '$@' **"
	$(CC) -c -o $@ $< $(CXXFLAGS)

%.o:	%.cpp $(CONFIG_TEST)
	@echo "** Compiling '$@' **"
	$(CC) -c -o $@ $< $(CFLAGS)

%.d: %.cpp  $(CONFIG_TEST)
	$(CC) -MM $(CFLAGS) -I. $(@:.d=.cpp) -MT $(@:.d=.o) > $(@:.cpp=.d)

%.d: %.cxx
	$(CC) -MM $(CXXFLAGS) $(@:.d=.cxx) -MT $(@:.d=.o) > $(@:.cpp=.d)

