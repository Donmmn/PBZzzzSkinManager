@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 exit /b 1
cd /d "%~dp0..\Tools"
cl /nologo /utf-8 /std:c++17 /EHsc /LD /MT /O2 /W4 /GS ..\source\PBZCinematicAudio.cpp /Fe:PBZCinematicAudio.dll /link /DYNAMICBASE /NXCOMPAT mfreadwrite.lib mfplat.lib mfuuid.lib ole32.lib winmm.lib shell32.lib
