dataDir="/black/localhome/glerma/TESTDATA/AFQ_PIPELINE"
# docker run -ti --rm --entrypoint /bin/bash  \
docker run -ti --rm  \
	       -v $dataDir/input:/flywheel/v0/input  \
   	       -v $dataDir/output:/flywheel/v0/output  \
           -v $(pwd)/example_config.json:/flywheel/v0/config.json \
   	       scitran/afq-pipeline:$1
