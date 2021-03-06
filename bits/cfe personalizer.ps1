﻿##
## If you are running this script independant of The Badger, you should 
## edit the $cfe filenames below to reflect the entire path to the files.
## e.g. c:\users\you\folder\original_cfe.bin   ...etc...
##


$cfe     = 'original_cfe.bin'
$cfe_new = 'new_cfe.bin'
$cfe_bak = 'new_cfe.bin.bak'

$macpatt = "(([0-9A-FX]{2}\:){5}[0-9A-FX]{2})" # note the X in there for "XX:XX:XX..." prepped cfe's
$wpspatt = "([0-9X]{8})"

$neederror = @"

** This tool requires both $cfe and $cfe_new to be in the same directory as The Badger   <
**  $cfe = created from your router, and containing its MAC addresses and WPS key        <
**  $cfe_new = any other CFE file (of a version you want) which gets personalized via    <
**  the MAC/WPS info from $cfe.                                                          <
** Note: $cfe is created by menu (F) of The Badger. You must download a $cfe_new         <
**  yourself (since I don't want to host them). Most people probably will want version   <
**  1.0.2.0 (US) which can be found in the "tmo2ac68u" package listed here:              <
**  https://wiki.dd-wrt.com/wiki/index.php/Asus_T-Mobile_Cellspot                        <
**  or by just spending a couple minutes googling for it. It should have a .bin suffix   <
**  and you should rename it to $cfe_new yourself.                                       <
**                                                                                       <
** Re-run this tool when both files are present.                                         <

"@
$bakerror = @"

** This tool copies $cfe_new to a backup file named $cfe_bak, but that file already      <
** exists. Out of abundance of caution, you must move that file before continuing.       <
**                                                                                       <
** Re-run this tool after doing so.                                                      <

"@
$exoticerror = @"

** This tool expects CFE .bin files with a very specific format, but it seems that       <
** one or both of your CFE files have the wrong number of MAC addresses appearing        <
** within. Out of an abundance of caution, we cannot proceed until you provide CFE       <
** .bin files that fit the expected format.                                              <
**                                                                                       <
** Re-run this tool after doing so.                                                      <

"@

$test_cfe1 = test-path($cfe)
$test_cfe2 = test-path($cfe_new)
$test_cfe3 = test-path($cfe_bak)
if(-not $test_cfe1 -or -not $test_cfe2){
	write-host -backgroundcolor red $neederror
	pause
	exit
}
if( $test_cfe3 ){
	write-host -backgroundcolor red $bakerror
	pause
	exit
}

$count_orig = (select-string -encoding default -path $cfe -pattern "macaddr=$macpatt").matches.groups.count
$count_new  = (select-string -encoding default -path $cfe_new -pattern "macaddr=$macpatt").matches.groups.count
if($count_orig -ne 3 -or $count_new -ne 3){
	write-host -backgroundcolor red $exoticerror
	pause
	exit
}



# NOTE: Yes, I'm fully aware this code could be made (a lot) cleaner by
#  using some list/array to store this stuff, and later iterate through
#  in a simple loop... but I want this to be as readable as possible
#  by people without much coding experience.

# first we find the required patterns in original_cfe.bin
# (we're most interested in the returned string values)
$keep1 = select-string -encoding default -path $cfe -pattern "et0macaddr=$macpatt"
$keep2 = select-string -encoding default -path $cfe -pattern "0\:macaddr=$macpatt"
$keep3 = select-string -encoding default -path $cfe -pattern "1\:macaddr=$macpatt"
$keep4 = select-string -encoding default -path $cfe -pattern "secret_code=$wpspatt"

# then we find the same patterns in new_cfe.bin
# (we're most interested in the returned byte-locations)
$kill1 = select-string -encoding default -path $cfe_new -pattern "et0macaddr=$macpatt"
$kill2 = select-string -encoding default -path $cfe_new -pattern "0\:macaddr=$macpatt"
$kill3 = select-string -encoding default -path $cfe_new -pattern "1\:macaddr=$macpatt"
$kill4 = select-string -encoding default -path $cfe_new -pattern "secret_code=$wpspatt"

# to keep the code readable, we're explicitly labeling everything
#   * byte-addresses of the 4 matches we want to copy to new_cfe.bin
#   * string-value of the 4 matches (MAC addrress/WPS code) we're keeping
#   * byte-values of the 4 matches we're keeping
# and we are writing over the new_cfe.bin with that info
#   * byte-addresses of the 4 matches we're writing over ("kill"ing)
#   * string-values of the 4 matches we're writing over, for logging
$keep1_addr = $keep1.Matches.Groups[1].Index # byte-address of first matched byte of 1st MAC-to-keep
$keep2_addr = $keep2.Matches.Groups[1].Index # byte-address of first matched byte of 2nd MAC-to-keep
$keep3_addr = $keep3.Matches.Groups[1].Index
$keep4_addr = $keep4.Matches.Groups[1].Index
$keep1_val  = $keep1.Matches.Groups[1].Value # string-value of 1st MAC-to-keep
$keep2_val  = $keep2.Matches.Groups[1].Value # string-value of 2nd MAC-to-keep
$keep3_val  = $keep3.Matches.Groups[1].Value
$keep4_val  = $keep4.Matches.Groups[1].Value
$keep1_valB = [system.text.encoding]::ASCII.GetBytes($keep1_val) # byte values of the 1st mac in the cfe
$keep2_valB = [system.text.encoding]::ASCII.GetBytes($keep2_val) # Needed both for sanity-check reads, and
$keep3_valB = [system.text.encoding]::ASCII.GetBytes($keep3_val) # for overwriting bytes of target cfe
$keep4_valB = [system.text.encoding]::ASCII.GetBytes($keep4_val) # note this (WPS code) is only 8 bytes
$kill1_addr = $kill1.Matches.Groups[1].Index
$kill2_addr = $kill2.Matches.Groups[1].Index
$kill3_addr = $kill3.Matches.Groups[1].Index
$kill4_addr = $kill4.Matches.Groups[1].Index
$kill1_val  = $kill1.Matches.Groups[1].Value
$kill2_val  = $kill2.Matches.Groups[1].Value
$kill3_val  = $kill3.Matches.Groups[1].Value
$kill4_val  = $kill4.Matches.Groups[1].Value


#
# This next big chunk is purely for informational logging/notification.
# A savvy user could use HxD to visit the stated addresses and verify.
# Also, a visual sanity check for the user.
# 
# ex:   38:2C:4A:EF:3E:88 [1233 / 0x4d1] <-- et0macaddr=38:2C:4A:EF:3E:88
#       |                  |                 |
#   mac pattern            |                 |
#              byte-0 decimal/hex address    |
#                                    full matched pattern
#
$reporting = @"

original_cfe.bin
* $keep1_val [$keep1_addr / $([String]::Format("0x{0:x3}", $keep1_addr))] <-- $($keep1.matches.value)
* $keep2_val [$keep2_addr / $([String]::Format("0x{0:x3}", $keep2_addr))] <-- $($keep2.matches.value)
* $keep3_val [$keep3_addr / $([String]::Format("0x{0:x3}", $keep3_addr))] <-- $($keep3.matches.value)
* $keep4_val [$keep4_addr / $([String]::Format("0x{0:x3}", $keep4_addr))] <-- $($keep4.matches.value)

new_cfe.bin (before patching)
* $kill1_val [$kill1_addr / $([String]::Format("0x{0:x3}", $kill1_addr))] <-- $($kill1.matches.value)
* $kill2_val [$kill2_addr / $([String]::Format("0x{0:x3}", $kill2_addr))] <-- $($kill2.matches.value)
* $kill3_val [$kill3_addr / $([String]::Format("0x{0:x3}", $kill3_addr))] <-- $($kill3.matches.value)
* $kill4_val [$kill4_addr / $([String]::Format("0x{0:x3}", $kill4_addr))] <-- $($kill4.matches.value)

"@
write-host $reporting -foregroundColor yellow
write-host ''

#
# SANITY CHECK #1
#
# open the CFE for read-checks
# read into 17-byte array
# compare array with keep_val
#
$bytes = New-Object -TypeName Byte[] -ArgumentList 17
$bytes.clear()                              # zeroes all 17 elements of $bytes (unnecessary but nice)
$fs = [IO.File]::OpenRead($cfe)             # open original_cfe.bin as filestream "$fs" (for reading)
$fs.Seek($keep3_addr,'Begin') | out-null    # set the "current" address to presumed address of keep3_val
$fs.Read($bytes,0,17) | out-null            # read 17 bytes from cfe into the 17-byte buffer, "$bytes"
$fs.close()
$bytes_as_string = [System.Text.Encoding]::ASCII.GetString($bytes)
if( $bytes_as_string -eq $keep3_val ){
    write-host -foregroundcolor green "1st (read-address) sanity check passed :)"
}else{
    write-host -backgroundcolor red "fail! bytes read from $cfe didn't match the expected mac-address pattern."
    pause
}


#
# SANITY CHECK #2
#
# now we repeat the process to check address validity in the other (new) cfe filestream
# (since it's a different origin, who knows, maybe it has different encoding)
#
$bytes.clear()                              # zeroes all 17 elements of $bytes (good idea now)
$fs = [IO.File]::OpenRead($cfe_new)         # open new_cfe.bin as filestream "$fs" (for reading)
$fs.Seek($kill3_addr,'Begin') | out-null    # set the "current" address to presumed address of kill3_val
$fs.Read($bytes,0,17) | out-null            # read 17 bytes from cfe into the 17-byte buffer, "$bytes"
$fs.close()
$bytes_as_string = [System.Text.Encoding]::ASCII.GetString($bytes)
if( $bytes_as_string -eq $kill3_val ){
    write-host -foregroundcolor green "2nd (read-address) sanity check passed :)"
}else{
    write-host -backgroundcolor red "fail! bytes read from $cfe_new didn't match the expected mac-address pattern."
    pause
}



#
# ACTUAL PERSONALIZATION OF new_cfe.bin
#
# go to each to-kill address... overwrite-in the value of each to-keep match
# (note: just the first match-group, not "full match pattern"... this allows
# one more sanity check later to verify the full-match-pattern in the new file
# matches that of the orig file, after we only wrote the first group value.)
#
write-host ''
write-host "** Backing up $cfe to $cfe_bak..."
cp $cfe_new $cfe_bak
write-host ''
write-host "** Now using critical vals from original_cfe.bin to overwrite those in $cfe_new"
write-host ''
$fs = [IO.File]::OpenWrite($cfe_new) 
$fs.seek($kill1_addr, 'Begin') | out-null
$fs.write($keep1_valB, 0, 17) | out-null
$fs.seek($kill2_addr, 'Begin') | out-null
$fs.write($keep2_valB, 0, 17) | out-null
$fs.seek($kill3_addr, 'Begin') | out-null
$fs.write($keep3_valB, 0, 17) | out-null
$fs.seek($kill4_addr, 'Begin') | out-null
$fs.write($keep4_valB, 0, 8) | out-null # we only have 8 bytes cuz WPS code
$fs.close()



#
# SANITY CHECK #3
#
# since we only wrote the core mac/wps pattern to new_cfe.bin, if we grep
# again for the 4 full patterns, and all match the original 4 full patterns
# then we have verified the expected writes all landed perfectly.
#
$check1 = select-string -encoding default -path $cfe_new -pattern "et0macaddr=$macpatt"
$check2 = select-string -encoding default -path $cfe_new -pattern "0\:macaddr=$macpatt"
$check3 = select-string -encoding default -path $cfe_new -pattern "1\:macaddr=$macpatt"
$check4 = select-string -encoding default -path $cfe_new -pattern "secret_code=$wpspatt"

if(      ($keep1.Matches.value -eq $check1.Matches.value) `
    -and ($keep2.Matches.value -eq $check2.Matches.value) `
    -and ($keep3.Matches.value -eq $check3.Matches.value) `
    -and ($keep4.Matches.value -eq $check4.Matches.value) )
{
    write-host -foregroundcolor green "3rd (pattern-compare) sanity check passed :)"
}else{
    write-host -backgroundcolor red "Somehow one of the $cfe_new patterns doesn't match $cfe."
}

write-host ''
write-host "If all 3 sanity checks passed, your $cfe_new should be ready to upload. (Hit enter to end.)"
write-host ''
pause


#
# Convert string to byte array:
#  [system.text.encoding]::ASCII.GetBytes("AA:BB:CC:DD:EE:FF")
#
# Convert byte array to string:
#  [System.Text.Encoding]::ASCII.GetString($bytes)
#
