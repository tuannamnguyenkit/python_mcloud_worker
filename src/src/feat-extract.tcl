if [catch {itfParseArgv janus $argv [list \
    [ list -adc string {} adc  {} "name of the audiofile"] \
    [ list -out string {} out  {} "name of the audiofile"] \
]} msg] { error "$msg" }

puts "Reading $adc"

set uttInfo [list [list UTT $adc]]
[FeatureSet fes] setDesc @featDesc

fes eval $uttInfo
puts [fes:FEAT configure]

[KaldiWriter wk] open "$out"
wk write fes:FEAT.data "utt0"
#puts [wk offset]
wk close

puts "Writing to $out"

exit
