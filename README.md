[![Docker Pulls](https://img.shields.io/docker/pulls/scitran/afq-pipeline.svg)](https://hub.docker.com/r/scitran/afq-pipeline/)
[![Docker Stars](https://img.shields.io/docker/stars/scitran/afq-pipeline.svg)](https://hub.docker.com/r/scitran/afq-pipeline/)

# RTP pipeline
Reproducible Tract Profiles pipeline. 

Reproducible Tract Profiles (RTP) comprises a set of methods to manage and analyze diffusion weighted imaging (DWI) data for reproducible tractography. The tools take MRI data from the scanner and process them through a series of analysis implemented as Docker containers that are integrated into a modern neuroinformatics platform (Flywheel). The platform guarantees that the entire pipeline can be re-executed, using the same data and computational parameters. In this paper, we describe (1) a cloud based neuroinformatics platform, (2) a tool to programmatically access and control the platform from a client, and (3) the DWI analysis tools that are used to identify the positions of 22 tracts and their diffusion profiles. The combination of these three components defines a system that transforms raw data into reproducible tract profiles for publication.

RTP uses parts of these tools (depending on the selected options):
1. mrTrix 3 
2. mrVista, mrDiffusion and AFQ
3. Ensemble Tractography (ET)
4. LiFE/SIFT2(TODO)
5. ANTs
6. SPM


The documentation is in the wiki:
* [Installation](https://github.com/vistalab/RTP-pipeline/wiki/Installation)
* [Pipeline documentation](https://github.com/vistalab/RTP-pipeline/wiki/Pipeline-steps)
* [Parameter recommendations](https://github.com/vistalab/RTP-pipeline/wiki/Parameter-recommendations): differences in acquisition sequences or subject populations require to use different parameters, in this page we collect the parameters and pipeline versions we used for better results. 
* [Reporting and citation](reporting-citation) In this wiki page we include examples of how to report and cite RTP and all the included tools, it will change depending on the selected tools. 
* [TO-DO list](https://github.com/vistalab/RTP-pipeline/wiki/TO-DO)


theme:minima 
