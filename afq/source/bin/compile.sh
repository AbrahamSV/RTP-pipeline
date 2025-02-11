#!/bin/bash

cat > build.m <<END

addpath(genpath('/bcbl/home/home_g-m/glerma/GIT/RTP-pipeline'));
rmpath(genpath('/bcbl/home/home_g-m/glerma/GIT/RTP-pipeline/local'));

addpath(genpath('/bcbl/home/home_g-m/glerma/toolboxes/jsonlab'));
addpath(genpath('/bcbl/home/home_g-m/glerma/toolboxes/JSONio'));

addpath(genpath('/bcbl/home/home_g-m/glerma/GIT/brain-life/encode'));
addpath(genpath('/bcbl/home/home_g-m/glerma/GIT/brain-life/app-life'));

addpath(genpath('/bcbl/home/home_g-m/glerma/toolboxes/freesurfer_mrtrix_afni_matlab_tools'));


mcc -m -R -nodisplay -a /bcbl/home/home_g-m/llecca/RTP-pipeline/afq/includeFiles -a /bcbl/home/home_g-m/llecca/brain-life/encode/mexfiles  -d compiled RTP.m

exit
END
/opt/R2020b/llecca/bin/matlab -nodisplay -nosplash -r build && rm build.m


# The compiled file is bigger than 100Mb, then it fails when pushing to github
# Use the command below to delete it from all history
# Add a gitignore so that it never goes back anything in the /compiled folder
# git filter-branch --force --index-filter 'git rm --cached --ignore-unmatch /data/localhome/glerma/soft/afq-pipeline/afq/source/bin/compiled/AFQ_StandAlone_QMR' --prune-empty --tag-name-filter cat -- --all
