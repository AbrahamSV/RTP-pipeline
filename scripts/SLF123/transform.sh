#!/bin/bash

# setting variables
while getopts "b:d:p:t:h:u:g:m:q:c:a:" opt;do
	case $opt in
		b) BASEDIR="$OPTARG";;
		d) codedir="$OPTARG";;
		p) MNI_package="$OPTARG";;
		t) MNI_template="$OPTARG";;
		h) host="$OPTARG";;
		u) qsub="$OPTARG";;
		g) logdir="$OPTARG";;
		m) mem="$OPTARG";;
		q) que="$OPTARG";;
		c) core="$OPTARG";;
		a) ants_ver="$OPTARG";;
	esac
done	

# look for the MNI template folder, if it does not exist, we create the folder and unzip the template
# if [[ ! -d ${BASEDIR}/$MNI_package ]]; then
# if [[ -f ${BASEDIR}/${MNI_package}.zip ]]; then
# mkdir ${BASEDIR}/$MNI_package
# unzip -d ${BASEDIR}/$MNI_package ${BASEDIR}/${MNI_package}.zip
# else
# printf "Please, provide the ${MNI_package}.zip template \n" 
# exit 1
# fi
# fi

# for loop for subjects in the DB
# for proj in $(cat ${BASEDIR}/subjectList.txt);do

while IFS=, read -r proj ses; do
    printf "\n\nWorking on $proj $ses \n"
    MRI_DIR=${BASEDIR}/sub-${proj}/ses-${ses}/output/flywheel/v0/output/RTP/fs
    ROI_DIR=${BASEDIR}/sub-${proj}/ses-${ses}/output
    
    if [ "$qsub" == "true" ];then
    
        if [ "$host" == "BCBL" ];then	
            qsub -q $que -N sub_${proj}_transform \
                 -o ${logdir}/${proj}_transform.o \
                 -e ${logdir}/${proj}_transform.e \
                 -l mem_free=$mem \
                 -v roidir=${ROI_DIR},MRI_DIR=${MRI_DIR},ants_ver=$ants_ver,BASEDIR=${BASEDIR} \
                 ${codedir}/runANTsApplyTransforms.sh	
        fi
        
        if [ "$host" == "DIPCfdr" ];then
            qsub -q $que -l mem=$mem,nodes=1:ppn=$core \
            	 -N sub_$[proj]_transform \
            	 -o ${logdir}/${proj}_transform.o \
            	 -e ${logdir}/${proj}_transform.e \
            	 -v roidir=${ROI_DIR},MRI_DIR=${MRI_DIR},ants_ver=$ants_ver,BASEDIR={$BASEDIR} \
            	 ${codedir}/runANTsApplyTransforms.sh
        fi
    
        if [ "$host" == "DIPCedr" ];then
            sbatch -q serial --partition=serial --mem=$mem --nodes=1 \
                       --cpus-per-task=$core --time=1-00:00:00 \
                       --job-name=${proj}_${ses} \
        	           -o ${logdir}/${proj}_${ses}_transf_structuralSyN.o \
        	           -e ${logdir}/${proj}_${ses}_transf_structuralSyN.e \
        	           --export=ALL,output=${MRI_DIR},roidir=${ROI_DIR},MRI_DIR=${MRI_DIR},ants_ver=$ants_ver,BASEDIR=${BASEDIR} \
            	       ${codedir}/runANTsApplyTransforms.sh
        fi
    
    else
        antsApplyTransforms -d 3 \
        -i ${ROI_DIR}/${roiname}.nii.gz \
        -r ${MRI_DIR}/antsWarped.nii.gz \
        -n BSpline \
        -t ${MRI_DIR}/ants1Warp.nii.gz \
        -t ${MRI_DIR}/ants0GenericAffine.mat \
        -o ${ROI_DIR}/${roiname}-MNISegment.nii.gz
    fi

done < ${BASEDIR}/subjectList.txt
