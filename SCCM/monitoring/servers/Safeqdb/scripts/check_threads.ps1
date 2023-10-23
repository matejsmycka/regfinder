$threads = (Get-Process * |Select-Object -ExpandProperty Threads).Count
$max = 5000

if ($threads -gt $max) 
{
  write-host "WARN: Threas count $threads"
  exit 1
}
else
{
  write-host "OK: Threads count $threads"
  exit 0
}