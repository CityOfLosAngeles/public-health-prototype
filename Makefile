.PHONY: pip conda install mirror

conda: conda-requirements.txt
	conda install -c conda-forge --yes --file conda-requirements.txt

pip: requirements.txt
	pip install -r requirements.txt
	pip install -e .

install: conda pip

mirror:
	intake-dcat mirror manifest.yml > catalogs/open-data.yml