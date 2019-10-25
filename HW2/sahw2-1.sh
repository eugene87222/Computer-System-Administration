#!/bin/sh

ls -lAR | sort -nr -k5 | awk 'BEGIN { dir = 0; file = 0; total = 0; } { if ($1 ~ /^d/) { dir += 1; } else if ($1 ~ /^-/) { file += 1; total += $5; if ( file <= 5 ) { print file":"$5" "$9; } } } END { print "Dir num: "dir"\nFile num: "file"\nTotal: "total; }'