path ..\BC31;%PATH%
call !clean.bat
tasm /m *.asm
@pause
bcc @bccopt.opt -c -mt *.cpp
@pause
tlink /t @link.cmd
@pause
