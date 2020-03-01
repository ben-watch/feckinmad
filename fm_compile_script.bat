@echo off

:: Makes current directory the working directory, saving the current one in memory
pushd "%~dp0"

::set output dir for .amxx file
set PLUGINS_DIR=.\plugins

:: Echo the stuff we need for the plugins into .inc files
echo stock const FM_SCRIPT_DATE[] = "%DATE%" > feckinmad\fm_script_version.inc
echo stock const FM_SCRIPT_NAME[] = "%~n1" > feckinmad\fm_script_name.inc 

:: Compile the plugin
tools\amxxpc.exe %1 -o%PLUGINS_DIR%\%~n1.amxx 

:: Delete these files to prevent other plugins accidently using them
del feckinmad\fm_script_version.inc
del feckinmad\fm_script_name.inc 

:: Return to the original working directory
popd

pause 