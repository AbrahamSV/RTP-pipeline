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
if [[ -z "$MNI_package" ]]; then  
    if [[ ! -d ${BASEDIR}/$MNI_package ]]; then
        if [[ -f ${BASEDIR}/${MNI_package}.zip ]]; then
            mkdir ${BASEDIR}/$MNI_package
            unzip -d ${BASEDIR}/$MNI_package ${BASEDIR}/${MNI_package}.zip
            templ=${BASEDIR}/${MNI_package}/${MNI_template}.nii.gz
        else
            printf "Please, provide the ${MNI_package}.zip template \n" 
            exit 1
        fi
    fi
else
    templ=${BASEDIR}/${MNI_template}.nii.gz
fi

# for loop for subjects in the DB
# for proj in $(cat ${BASEDIR}/subjectList.txt);do
while IFS=, read -r proj ses; do
    printf "\n\nWorking on $proj $ses \n"

    # MRI_DIR=${BASEDIR}/${proj}/structural
    MRI_DIR=${BASEDIR}/sub-${proj}/ses-${ses}/output/flywheel/v0/output/RTP/fs
    # echo $MRI_DIR


    if [ "$qsub" == "true" ];then
    
        if [ "$host" == "BCBL" ]; then
        printf "Registering structural to the MNI template \n" 
        qsub -q $que -N sub_${proj}_structural \
             -o ${logdir}/${proj}_structural.o \
             -e ${logdir}/${proj}_structural.e \
             -l mem_free=$mem \
             -v output=${MRI_DIR},template=$templ,ants_ver=$ants_ver,img=${MRI_DIR}/brain.nii.gz \
            ${codedir}/runANTsRegistrationSyN.sh
        fi
    
        if [ "$host" == "DIPCfdr" ]; then
            printf "Registering structural to the MNI template \n"
    
            qsub  -q $que -l mem=$mem,nodes=1:ppn=$core \
    	          -N sub_${proj}_structural \
    	          -o ${logdir}/${proj}_structuralSyN.o \
    	          -e ${logdir}/${proj}_structuralSyN.e \
    	          -v output=${MRI_DIR},template=$templ,ants_ver=$ants_ver,img=${MRI_DIR}/brain.nii.gz \
    	          ${codedir}/runANTsRegistrationSyN.sh
        fi
        
        if [ "$host" == "DIPCedr" ]; then
            printf "Registering structural to the MNI template in DIPCedr\n"
    
            sbatch -q serial --partition=serial --mem=$mem --nodes=1 \
                   --cpus-per-task=$core --time=1-00:00:00 \
                   --job-name=${proj}_${ses} \
    	           -o ${logdir}/${proj}_${ses}_reg_structuralSyN.o \
    	           -e ${logdir}/${proj}_${ses}_reg_structuralSyN.e \
    	           --export=ALL,output=${MRI_DIR},template=$templ,ants_ver=$ants_ver,img=${MRI_DIR}/brainmask.nii.gz \
    	           ${codedir}/runANTsRegistrationSyN.sh
        fi
    else
        module load $ants_ver
    
        antsRegistrationSyN.sh -d 3 -o ${MRI_DIR}/ants \
        -f ${BASEDIR}/${MNI_package}/${MNI_template}.nii.gz \
        -m ${BASEDIR}/${proj}/structural/brain.nii.gz
    
    fi
done < ${BASEDIR}/subjectList.txt
