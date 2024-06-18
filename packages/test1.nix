{ runCommand }:

runCommand "test1" { } ''echo test1 > $out''
