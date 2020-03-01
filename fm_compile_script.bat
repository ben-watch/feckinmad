@echo off

::set PLUGINS_DIR=
set PLUGINS_DIR="E:\SteamLibrary\steamapps\common\Half-Life\tfc\addons\amxmodx\plugins"

:: Makes current directory the working directory, saving the current one in memory
pushd "%~dp0"

:: Generate a md5 for the input file
tools\md5.exe -n %1 > tools\md5_temp

:: Copy the output from the md5 file into a local variable
copy tools\setmd5.bat + tools\md5_temp tools\$tmp$.bat > nul
del tools\md5_temp

::call tools\$tmp$.bat
del tools\$tmp$.bat

:: Echo the stuff we need for the plugins into .inc files
echo stock const FM_SCRIPT_MD5[] = "%SCRIPT_MD5%" > feckinmad\fm_script_md5.inc
echo stock const FM_SCRIPT_DATE[] = "%DATE%" > feckinmad\fm_script_version.inc
echo stock const FM_SCRIPT_NAME[] = "%~n1" > feckinmad\fm_script_name.inc 

:: Compile the plugin
tools\amxxpc.exe %1 -o%PLUGINS_DIR%\%~n1.amxx 

:: Delete these files to prevent other plugins accidently using them
del feckinmad\fm_script_md5.inc
del feckinmad\fm_script_version.inc
del feckinmad\fm_script_name.inc 

:: Return to the original working directory
popd

pause 