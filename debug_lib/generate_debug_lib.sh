#!/bin/bash

set -e -u -o pipefail

for f in ../src/*.ml{,i}; do
    b=$(basename $f)
    cat $f >$b.tmp
    case $b in
        incremental_kernel*)
            target=$(echo $b | sed -r 's/incremental_kernel/incremental_kernel_debug/')
            rm -f $target
            sed <$b.tmp >$target -r 's/Incremental_kernel/Incremental_kernel_debug/g'
            ;;
        *)
            target=$b
            mv $b.tmp $target
            ;;
    esac        
    chmod -w $target
    rm -f $b.tmp
done

