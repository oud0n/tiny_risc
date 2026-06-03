#! /bin/bash -f

# directory
if [[ -d "build" && -d "build.bk" ]]; then
    rm -r "build.bk";
fi

if [[ -d "build" ]]; then
    mv "build" "build.bk";
fi

mkdir build

#
python3 build.py