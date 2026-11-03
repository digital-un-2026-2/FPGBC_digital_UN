include ../include/generated/variables.mak
include $(SOC_DIRECTORY)/software/common.mak

OBJECTS = game_buttons.o

all: lib_unal.a

lib_unal.a: $(OBJECTS)
	$(AR) crs lib_unal.a $(OBJECTS)

-include $(OBJECTS.o=.d)

%.o: $(LIB_UNAL_DIRECTORY)/%.c
	$(compile)

.PHONY: all clean

clean:
	$(RM) $(OBJECTS)
	$(RM) lib_unal.a .*~ *~