# $args[0] = application name, e.g. bupa
# $args[1] = path, e.g. C:\www\bupa
# $args[2] = host name e.g. bupa.continuity2.com
# .\default.ps1 "bupa" "C:\www\bupa" "bupa.continuity2.com"
write-host $args.count
cscript .\iis6_create_site.vbs @($args[0], $args[1], $args[2])