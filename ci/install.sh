#!/bin/bash
conda create --yes --name testenv
source activate testenv
conda install --yes -c conda-forge --file conda-requirements.txt
pip install -r requirements.txt
