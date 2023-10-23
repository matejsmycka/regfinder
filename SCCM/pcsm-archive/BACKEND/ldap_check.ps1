function ldap_check(){
    Param(
        [string]$server
    )


$root = [ADSI]"LDAP://$server.ucn.muni.cz"

$search = [adsisearcher]$root

$Search.Filter = "(&(objectCategory=person)(name=418142))"

$colResults = $Search.FindAll()

foreach ($i in $colResults)
{
$user = $i.GetDirectoryEntry()


$objectSid = [byte[]]$user.objectSid[0]
$sid = New-Object System.Security.Principal.SecurityIdentifier($objectSid,0)
$sidString = ($sid.value).ToString()

Write-Output "$server : $(get-date -format "yyyy-MM-dd HH:mm:ss") | $($user.Name) | $($user.givenName) $($user.sn) | $($sidString)"
}
}






function ps_ldap(){
    Param(
        [string]$server
    )
    
    $data = (Get-ADUser -server ucn-server0.ucn.muni.cz -Identity "418142")
    Write-Output "$server : $(get-date -format "yyyy-MM-dd HH:mm:ss") | $($data.Name) | $($data.givenName) $($data.surname) | $($data.sid.value)"
}

"PS format" >> "C:\pcsm_backend\ldap\log.txt"
ps_ldap -server ucn-server0 >> "C:\pcsm_backend\ldap\log.txt"
ps_ldap -server ucn-server1 >> "C:\pcsm_backend\ldap\log.txt"
ps_ldap -server ucn-server2 >> "C:\pcsm_backend\ldap\log.txt"

"LDAP format" >> "C:\pcsm_backend\ldap\log.txt"
ldap_check -server ucn-server0 >> "C:\pcsm_backend\ldap\log.txt"
ldap_check -server ucn-server1 >> "C:\pcsm_backend\ldap\log.txt"
ldap_check -server ucn-server2 >> "C:\pcsm_backend\ldap\log.txt"
