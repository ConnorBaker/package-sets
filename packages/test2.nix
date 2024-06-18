{ runCommand }:

runCommand "test2" { } ''echo test2 > $out''
