CXX := wpp
LD := wlink
CXXFLAGS := -3 -j -ox -oh -zl -ms -bt=dos

LINLD.COM: _BEG.obj A20.obj XMM.obj VCPI.obj MEMCPY32.obj MEMTOP.obj CRTL.obj LOAD.obj HIMEM.obj _END.obj
	$(LD) system dos com $(addprefix file ,$^) name $@

%.obj: %.ASM
	nasm -f obj -t $^ -l $(patsubst %.ASM,%.lst,$^)

%.obj: %.CPP
	$(CXX) $(CXXFLAGS) $^ -fo=.obj -I.

clean:
	rm -f *.obj *.lst *.COM *.EXE

.PHONY: clean
