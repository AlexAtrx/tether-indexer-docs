#!/bin/bash

for dir in */; do
    src="${dir}gitignore"
    dst="${dir}.gitignore"
    if [[ -f "$src" ]]; then
        mv "$src" "$dst"
        echo "Renamed: $src -> $dst"
    fi
done