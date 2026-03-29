#!/bin/bash
set -e

mkdir -p raw_sources
cd raw_sources

echo "Cloning source repositories..."

if [ ! -d "mechvibes" ]; then
    echo "Cloning mechvibes..."
    git clone https://github.com/hainguyents13/mechvibes.git
else
    echo "mechvibes already exists."
fi

if [ ! -d "kbsim" ]; then
    echo "Cloning kbsim..."
    git clone https://github.com/tplai/kbsim.git
else
    echo "kbsim already exists."
fi

if [ ! -d "bucklespring" ]; then
    echo "Cloning bucklespring..."
    git clone https://github.com/zevv/bucklespring.git
else
    echo "bucklespring already exists."
fi

if [ ! -d "MKS" ]; then
    echo "Cloning MKS..."
    git clone https://github.com/x0054/MKS.git
else
    echo "MKS already exists."
fi

echo "Raw sources fetched successfully!"
