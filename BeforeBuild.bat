REM -ma5 - RAR5 format
REM -m5 - compression rate
REM -s - solid archive type
REM -dh - open shared files
"C:\Program Files\WinRAR\Rar.exe" d -idc sources.rar pmenu.xml
"C:\Program Files\WinRAR\Rar.exe" a -ma5 -m5 -dh -idc sources.rar pmenu.ico pmenu.lpi pmenu.lpr pmenu.res BeforeBuild.bat pmenu-sample.xml
"C:\Program Files\WinRAR\Rar.exe" rn -idc sources.rar pmenu-sample.xml pmenu.xml
rm -f sources.res
exit 0