CXX := wpp
CXXLD := wcl
CXXFLAGS := -3 -j -ox -oh

LINLD.COM: _END.obj A20.obj XMM.obj VCPI.obj MEMCPY32.obj MEMTOP.obj CRTL.obj LOAD.obj HIMEM.obj
	$(CXXLD) $(CXXFLAGS) -fe=$@ $^

%.obj: %.ASM
	nasm -f obj -t $^ -l $(patsubst %.ASM,%.lst,$^)

%.obj: %.CPP
	$(CXX) $(CXXFLAGS) $^ -fo=.obj -I.

clean:
	rm -f *.obj *.lst *.COM *.EXE

.PHONY: clean
