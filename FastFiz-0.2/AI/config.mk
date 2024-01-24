GSL_INCLUDES = $(shell gsl-config --cflags)
GSL_LIBS = $(shell gsl-config --libs)
CC = g++
OPTIMIZE = -g
CONFIG_TGZ = ../libconfig-1.3.tar.gz
CONFIG_PATH = ../libconfig-1.3
CONFIG_INC = -I$(CONFIG_PATH)
CONFIG_LIB = $(CONFIG_PATH)/.libs/libconfig++.a
FASTFIZ_LIB = ../FastFiz/FastFiz.a
FASTFIZ_INC = -I../FastFiz
INCLUDES = -I. $(CONFIG_INC) $(FASTFIZ_INC) $(GSL_INCLUDES)
TARGET_DIR = .

CFLAGS= $(OPTIMIZE) -Wall -Wno-deprecated $(INCLUDES) -fPIC
LDFLAGS = $(INCLUDES) -O1 -finline-functions -ffast-math
LIBS = -lc $(GSL_LIBS) $(shell python-config --libs) \
        $(FASTFIZ_LIB)

%.o:	%.cpp $(CONFIG_PATH)
	@echo "** Compiling '$@' **"
	$(CC) -c -o $@ $< $(CFLAGS)

%.d: %.cpp $(CONFIG_PATH)
	$(CC) -MM $(CFLAGS) -I. $(@:.d=.cpp) -MT $(@:.d=.o) > $(@:.cpp=.d)
