FROM irose/citywide-jupyterlab:b649e350f0c9

COPY conda-requirements.txt /tmp/
RUN conda install --yes -c conda-forge --file /tmp/conda-requirements.txt

COPY requirements.txt /tmp/
RUN pip install -r /tmp/requirements.txt

RUN pip install -U jupyterlab
