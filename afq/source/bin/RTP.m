function RTP(jsonargs)
%
% RTP_StandAlone_QMR(jsonargs)
%
% INPUT ARGUMENTS: Note: must be a json string.
%
%       input_dir:  Directory containing dt6.mat
%       output_dir: Location to save the results
%       params:     Key-Value pair of params for RTP_Create
%{
% EXAMPLE USAGE:
    jsonargs = "/bcbl/home/home_g-m/glerma/GIT/RTP-pipeline/afq/source/pruebas.json";
   
 
    jsonargs = "/export/home/glerma/TESTDATA/DWIpipeline/Nifti/derivatives/rtp-pipeline_4.3.9/analysis-01/output_parsed.json";
    RTP(jsonargs);


%}
%
%#ok<*AGROW>

%% Begin
disp('[RTP] Starting RTP...');
datestamp = strrep(char(datetime(datestr(now),'TimeZone','local','Format','yyyy-MM-dd''T''HH:mm:ssz')),':','_');
disp(['[RTP] datestamp:', datestamp]);

% Initialize args
input_dir       = [];
output_dir      = [];
params          = [];
anat_dir        = [];
bval_dir        = [];
bvec_dir        = [];
fs_dir          = [];
nifti_dir       = [];
tractparams_dir = [];
save_output     = [];
segmentSLF      = [];

%% Handle jsonargs
disp('[RTP] This is the json string to be read by loadjson:')
%jsonargs = '/export/home/llecca/llecca/RTP-pipeline/local/parsed_config.json';
%disp(jsonargs)

% Read the file in the variable P
if exist('jsonargs', 'var') && ~isempty(jsonargs)
    P = jsondecode(fileread(jsonargs));
end
disp('[RTP] Contents of the config json file are:');
P

%% Configure inputs and defaults, get rid of P:
input_dir       = P.input_dir;
output_dir      = P.output_dir;
params          = P.params;
anat_dir        = P.anat_dir;
bval_dir        = P.bval_dir;
bvec_dir        = P.bvec_dir;
fs_dir          = P.fs_dir;
nifti_dir       = P.nifti_dir;
tractparams_dir = P.tractparams_dir;
save_output     = params.save_output;
segmentSLF      = params.track.segmentSLF;

fprintf('Save afq output: %s\n',  string(save_output));
fprintf('SLF segmentation: %s\n',  string(segmentSLF));

% Obtain the input filenames
input_t1        = dir(fullfile(anat_dir ,'*.nii.gz'))   ;
input_t1        = fullfile(input_t1.folder   ,input_t1.name);

input_bvec      = dir(fullfile(bvec_dir ,'*.bvec*'))    ;
input_bvec      = fullfile(input_bvec.folder ,input_bvec.name);

input_bval      = dir(fullfile(bval_dir ,'*.bval*'))    ;
input_bval      = fullfile(input_bval.folder ,input_bval.name);

input_dwi       = dir(fullfile(nifti_dir,'*.nii.gz'))   ;
input_dwi       = fullfile(input_dwi.folder  ,input_dwi.name);

input_fszip     = dir(fullfile(fs_dir   ,'*.zip'))      ;
input_fszip     = fullfile(input_fszip.folder,input_fszip.name);

input_csv       = dir(fullfile(tractparams_dir,'*.csv'));
input_csv       = fullfile(input_csv.folder  ,input_csv.name);

%% Copy input files to working directory
% Create the destination input filenames
rtp_dir         = fullfile(output_dir,'RTP');
if ~exist(rtp_dir)  % ;error('[RTP] rtp_dir exists in %s', rtp_dir)
    mkdir(rtp_dir);
end

% We need these files in root dir (rtp_dir) to start working
t1_file         = fullfile(rtp_dir, 't1.nii.gz');
bvec_file       = fullfile(rtp_dir, 'dwi.bvecs');
bval_file       = fullfile(rtp_dir, 'dwi.bvals');
dwi_file        = fullfile(rtp_dir, 'dwi.nii.gz');
fs_file         = fullfile(rtp_dir, 'fs.zip');
csv_file        = fullfile(rtp_dir, 'params.csv');

% Copy input files to output/RTP/
copyfile(input_t1   , t1_file)  ;
copyfile(input_bvec , bvec_file);
copyfile(input_bval , bval_file);
copyfile(input_dwi  , dwi_file) ;
copyfile(input_fszip, fs_file)  ;
copyfile(input_csv  , csv_file) ;

% Check if copied properly
if ~exist(t1_file)  ; error('[RTP] %s file is not there', t1_file)  ; end
if ~exist(bvec_file); error('[RTP] %s file is not there', bvec_file); end
if ~exist(bval_file); error('[RTP] %s file is not there', bval_file); end
if ~exist(dwi_file) ; error('[RTP] %s file is not there', dwi_file) ; end
if ~exist(fs_file)  ; error('[RTP] %s file is not there', fs_file)  ; end
if ~exist(csv_file) ; error('[RTP] %s file is not there', csv_file) ; end

% Unzip the output from FS
unzip(fs_file, rtp_dir)
% Check if the expected folders are here, and the minumun files so that the rest does not fail
if ~exist(fullfile(rtp_dir,'fs'),'dir');error('[RTP] fs folder does not exist, check the fs.zip file');end
if ~exist(fullfile(rtp_dir,'fs','ROIs'),'dir');error('[RTP] fs/ROIs folder does not exist, check the fs.zip file');end
if ~exist(fullfile(rtp_dir,'fs','aparc+aseg.nii.gz'),'file');error('[RTP] fs/ROIs/aparc+aseg.nii.gz file does not exist, check the fs.zip file');end
if ~exist(fullfile(rtp_dir,'fs','brainmask.nii.gz'),'file');error('[RTP] fs/ROIs/brainmask.nii.gz file does not exist, check the fs.zip file');end

% RTP dir will be zipped at the end, the whole dir output_dir will be the output
% in FW, it will have the RTP dir and the files we want to be accesible for
% reading in FW output Only one subject, but until changed this is a cell array
sub_dirs{1} = rtp_dir;

%% Initialize diffusion parameters. This was for dtiInit and dt6Creation.
% Not really required. TODO: remove this
dwParams            = dtiInitParams;
dwParams.outDir     = output_dir;
dwParams.bvecsFile  = bvec_file;
dwParams.bvalsFile  = bval_file;

%% Validate that the bval values are normalized
% Determine shell
bvals            = dlmread(bval_file);
roundedBval      = 100 * round(bvals/100);
paramsShells     = unique(roundedBval);
if 0 == min(paramsShells)
    paramsShells = paramsShells(paramsShells ~= 0);
    numShells    = length(paramsShells);
else
    error('[RTP] It seems that this file have no b0. Check it please.')
end

% Write the files back
warning('[RTP] The bVals were normalized.')
dlmwrite(bval_file, roundedBval, 'delimiter',' ');

%% Run (the equivalent ) dtiInit
% From 3.0.5 onwards I am forking dtiInit and giving it less
% functionalities. I will remove the tensor fitting and do it with mrTrix,
% it is much faster and the rest of the code relies in it anyways.
% First iteration, stop dtiInit doing it and later on mrtrixInit will paste
% the fa to the bin folder.
% 3.1.1 it was doing nothing already
% 3.1.2 I am removing the call altogether to make this thing simpler
%        AFQ_dtiInit(J.dwi_file, J.t1_file, dwParams);
% 3.2.0: remove afq-browser and dtiInit altogether
% 4.0.0 now, that we already removed dtiInit and afq-browser.
% 4.2.0 reads csv and creates tracts table, now any tract can be done
% 4.2.1 ROIs: dilates and concatenates them

% Here dtiInit was called, assign variables
dwRawFileName = dwi_file;
t1FileName    = t1_file;

% I. Load the diffusion data, set up parameters and directories structure
% Load the difusion data
disp('[RTP] Loading preprocessed (use rtp-preproc or already preprocessed) data...');
dwRaw = niftiRead(dwRawFileName);
dwParams.dwOutMm = dwRaw.pixdim(1:3);

% Initialize the structure containing all directory info and file names
% dwDir      = dtiInitDir(dwRawFileName,dwParams);
dwDir.outSuffix        = ''
dwDir.mrDiffusionDir   = mrdRootPath();
dwDir.dataDir          = rtp_dir;
dwDir.inBaseName       = 'dwi'
dwDir.subjectDir       = dwDir.dataDir;
dwDir.mnB0Name         = fullfile(dwDir.dataDir, 'dwi_b0.nii.gz');
dwDir.outBaseName      = ''
dwDir.outBaseDir       = dwDir.dataDir
dwDir.inBaseDir        = fullfile(dwDir.dataDir,'dwi');
dwDir.bvalsFile        = fullfile(dwDir.dataDir,'dwi.bvals');
dwDir.bvecsFile        = fullfile(dwDir.dataDir,'dwi.bvecs');
dwDir.ecFile           = fullfile(dwDir.dataDir,'dwi_ecXform.mat');
dwDir.acpcFile         = fullfile(dwDir.dataDir,'dwi_acpcXform.mat');
dwDir.alignedBvecsFile = dwDir.bvecsFile;
dwDir.alignedBvalsFile = dwDir.bvalsFile;
dwDir.dwAlignedRawFile = dwi_file;

outBaseDir = dwDir.outBaseDir;
fprintf('[RTP] Dims = [%d %d %d %d] \nData Dir = %s \n', size(dwRaw.data), dwDir.dataDir);
fprintf('[RTP] Output Dir = %s \n', dwDir.subjectDir);

dwParams.dt6BaseName = fullfile(rtp_dir);
dt6FileName          = fullfile(rtp_dir, 'dt6.mat');
binDirName           = fullfile(rtp_dir, 'bin');
if(~exist(binDirName,'dir')) ;mkdir(binDirName);end
if(~exist('adcUnits','var')); adcUnits = ''; end


params.input_dir    = rtp_dir;
params.output_dir   = output_dir;
params.buildDate    = datestamp;
l = license('inuse');
params.buildId      = sprintf('%s on Matlab R%s (%s)',l(1).user,version('-release'),computer);
if(ischar(dwRawFileName)); [dataDir,rawDataFileName] = fileparts(dwRawFileName);  % dwRawAligned);
else                       [dataDir,rawDataFileName] = fileparts(dwRawFileName.fname);end  % dwRawAligned.fname); end
params.rawDataDir   = dataDir;
params.rawDataFile  = rawDataFileName;
params.subDir       = dataDir;
params.fs_dir       = fullfile(rtp_dir,'fs');
params.roi_dir      = fullfile(rtp_dir,'ROIs');
% These need to be relative to output_dir...
files.b0            = fullfile('RTP','bin','b0.nii.gz');
files.brainMask     = fullfile('RTP','bin','brainMask.nii.gz');
files.wmMask        = fullfile('RTP','bin','wmMask.nii.gz');
files.tensors       = fullfile('RTP','bin','tensors.nii.gz');
files.fa            = fullfile('RTP','bin','fa.nii.gz');

save(dt6FileName,'adcUnits','params','files');
dtiInitDt6Files(dt6FileName,dwDir,t1FileName);

%% CHECK IF INPUT IS RAS
% New in 3.1.2: check the file is RAS If not, convert to RAS Be careful, bvecs
% needs to be changed as well accordingly Instead of changing bvecs manually, we
% will let mrtrix take care of it Convert files to mif, add the bvecs and bvals
% as part of the file, do the conversion and then output the fsl type bvecs
% again. This we can maintain coherence in the whole process. Therefore, if
% there is a - in the strides or the order is not 123, we need to convert (with
% freesurfer it is easier because it gives you RAS or PIR or LAS or whatever but
% it is not installed in the Docker container)

% Read the input file names and convert them
basedir          = rtp_dir;

fprintf('[RTP] This is basedir for RAS checks: %s\n',   basedir)

J                = load(fullfile(rtp_dir,'dt6.mat'));
disp('[RTP] These are the contents of dt6.mat')
J.params.fs_dir  = fullfile(rtp_dir,'fs');
J.params.roi_dir = fullfile(rtp_dir,'fs','ROIs');
J.params
J.files

% DWI file
[p,f,e]= fileparts(J.files.alignedDwRaw);
if ~strcmp(p,basedir); J.files.alignedDwRaw = fullfile(basedir,[f e]); end

% BVEC file
[p,f,e]= fileparts(J.files.alignedDwBvecs);
if ~strcmp(p,basedir); J.files.alignedDwBvecs = fullfile(basedir,[f e]); end

% BVAL file
[p,f,e]= fileparts(J.files.alignedDwBvals);
if ~strcmp(p,basedir); J.files.alignedDwBvals = fullfile(basedir,[f e]); end

J.files.t1path    = fullfile(J.params.output_dir,J.files.t1);
fprintf('[RTP] This is the absolute path to the t1: %s\n', J.files.t1path)
if exist(J.files.t1path,'file')
    fprintf('[RTP] T1 file %s Exists. \n', J.files.t1path)
else
    error('[RTP] Cannot find %s', J.files.t1path)
end

% Check it in these files
checkfiles = {'alignedDwRaw','t1path'}; %,'aparcaseg'};
for nc=1:length(checkfiles)
    fname = J.files.(checkfiles{nc});
    [c2r,orientation] = rtp_convert2RAScheck(fname);
    if ~c2r
        fprintf('[RTP] %s has orientation %s (RAS), no transformation required.\n',fname,orientation)
    else
        fprintf('[RTP] %s has orientation %s, converting to 123(4) (RAS) \n',fname,orientation)
        [p,f,e] = fileparts(fname);
        % Check that it is .nii.gz
        if strcmp(e,'.gz')
            [~,f] = fileparts(f);
            e = '.nii.gz';
        elseif strcmp(e,'.nii')
            % do nothing
        else
            error('[RTP] File extension should be .nii.gz or .nii')
        end
        % If it is diffusion, we need to take care of gradients
        switch checkfiles{nc}
            case 'alignedDwRaw'
                % 1: Do the strides to RAS conversion
                fslRASname = fullfile(p,[f 'ras.nii.gz']);
                fslRASbvec = fullfile(p,[f 'ras.bvec']);
                fslRASbval = fullfile(p,[f 'ras.bval']);
                cmd = sprintf('mrconvert -quiet -force -fslgrad %s %s -stride 1,2,3,4  -export_grad_fsl %s %s %s %s', ...
                              J.files.alignedDwBvecs, J.files.alignedDwBvals,fslRASbvec,fslRASbval,fname, fslRASname);

                s = AFQ_mrtrix_cmd(cmd); if s~=0;error('[RTP] Could not change the strides to RAS');end
                % 2: change filenames to continue with processing normally
                J.files.alignedDwBvecs = fslRASbvec;
                J.files.alignedDwBvals = fslRASbval;
                J.files.alignedDwRaw   = fslRASname;
            otherwise
                % 1: Do the strides to RAS conversion
                fRASname = fullfile(p,[f 'ras.nii.gz']);
                cmd = sprintf('mrconvert -quiet -force -stride 1,2,3 %s %s', ...
                               fname, fRASname);
                s = AFQ_mrtrix_cmd(cmd); if s~=0;error('[RTP] Could not change the strides to RAS');end
                % 2: change filenames to continue with processing normally
                J.files.(checkfiles{nc}) = fRASname;
        end
    end
end

% check existence, dilation, combination of ROIs
A = ROIcheck(csv_file, J)

%% Create afq structure
disp('[RTP] Running AFQ_create with the following options...');
fprintf('[RTP] sub_dirs: %s', sub_dirs{1})
fprintf('[RTP] output_dir: %s', output_dir)
if ~exist(fullfile(rtp_dir,'bin'));mkdir(rtp_dir, 'bin');end
% Add deleted variables to afq, the ones we want constant
J.params.clip2rois        = false; % We tract without considering this, when obtaining metrics we use both true and false
J.params.track.multishell = false;
if length(paramsShells) > 1;J.params.track.multishell=true;end
J.params.track.tool       = 'freesurfer';
J.params.track.algorithm  = 'mrtrix';
J.params.computeCSD       = true;
afq = AFQ_Create(sub_dirs{1}, J.params, A);
disp('[RTP] ... end running AFQ_Create')

%% RUN RTP
disp(   '[RTP] Running AFQ_run with the following options...');
fprintf('[RTP] sub_dirs: %s', sub_dirs{1})
disp(   '[RTP] This is the afq struct going to AFQ_run');
afq
[afq, afq_C2ROI]= AFQ_run(sub_dirs, 1, afq);
disp('  ... end running AFQ_run');

%% Check for empty fiber groups
disp('[RTP] Checking for empty fiber groups...');
for i = 1:numel(afq.TractProfiles)
    if isempty(afq.TractProfiles(i).nfibers)
        disp(fprintf('Fiber group is empty: %s', afq.TractProfiles(i).name));
    end
end

% Write the afq file
% Save each iteration of afq run if an output directory was defined
outname = fullfile(rtp_dir,['afq_' datestamp]);
save(outname,'afq');
outname = fullfile(rtp_dir,['afq_C2ROI' datestamp]);
save(outname,'afq_C2ROI');



%% Export the data to csv files
disp('[RTP] Exporting data to csv files...');
% We will add the diffusion parameters and the series number to the name
csv_dir = fullfile(rtp_dir,'csv_files');
if ~exist(csv_dir,'dir');mkdir(csv_dir);end

% Get the names of each of the datatypes (e.g.,'FA','MD', etc.)
properties = fieldnames(afq.vals);

% Loop over the properties and create a table of values for each property
for ii = 1:numel(properties)

    % Loop over each fibergroup and insert the values into the table
    for i = 1:numel(afq.fgnames)

        % If this is the first time through create a table that we'll
        % concatenate with each following table (t)
        if i == 1
            T = cell2table(num2cell(afq.vals.(properties{ii}){i}'),'variablenames',{regexprep(afq.fgnames{i},' ','_')});
        else
            t = cell2table(num2cell(afq.vals.(properties{ii}){i}'),'variablenames',{regexprep(afq.fgnames{i},' ','_')});

            % Combine the tables
            T = horzcat(T,t);
        end

        % Write out the table to a csv file
        writetable(T,fullfile(csv_dir,['RTP_' lower(properties{ii}) '.csv']));
    end
end

% Do the same for the C2ROI
disp('[RTP] Exporting C2ROI data to csv files...');
% We will add the diffusion parameters and the series number to the name

% Get the names of each of the datatypes (e.g.,'FA','MD', etc.)
properties = fieldnames(afq_C2ROI.vals);

% Loop over the properties and create a table of values for each property
for ii = 1:numel(properties)
    % Loop over each fibergroup and insert the values into the table
    for i = 1:numel(afq_C2ROI.fgnames)
        % If this is the first time through create a table that we'll
        % concatenate with each following table (t)
        if i == 1
            T = cell2table(num2cell(afq_C2ROI.vals.(properties{ii}){i}'),'variablenames',{regexprep(afq_C2ROI.fgnames{i},' ','_')});
        else
            t = cell2table(num2cell(afq_C2ROI.vals.(properties{ii}){i}'),'variablenames',{regexprep(afq_C2ROI.fgnames{i},' ','_')});

            % Combine the tables
            T = horzcat(T,t);
        end

        % Write out the table to a csv file
        writetable(T,fullfile(csv_dir,['RTP_C2ROI' lower(properties{ii}) '.csv']));
    end
end




















%% Create the tck files for visualizing the results
disp('[RTP] Exporting tck files for QA...');
% We will add the diffusion parameters and the series number to the name
tck_dir    = fullfile(rtp_dir,'tck_files');
if ~exist(tck_dir,'dir');mkdir(tck_dir);end
% Copy only the tck files we want to visualize, so that we do not need to unzip the big RTP file
mrtrixdir  = fullfile(J.params.subDir,'mrtrix');
clean_tcks = dir(fullfile(mrtrixdir,'*clean*.tck'));
for nt=1:length(clean_tcks)
	srctckname = fullfile(mrtrixdir, clean_tcks(nt).name);
	dsttckname = fullfile(tck_dir  , clean_tcks(nt).name);
	dstplyname = fullfile(tck_dir  , strrep(clean_tcks(nt).name,'tck','ply'));
	% copyfile(srctckname,dsttckname)
	% Use the same step tc create the ply file in the vis folder. We wil convert them to obj with python
	% TODO: make it optional
	% cmd  = sprintf('tckconvert -force -dec %s %s', dsttckname, dstplyname);
	% rcmd = AFQ_mrtrix_cmd(cmd);
end

%TODO: add a flag, saveIntermediateFilesForQC
% It will show the files showns below in the results folder

%% Save reproducibility info
R                   = {};
R.date              = datestamp;
[~, R.arch]         = system('lsb_release -a');
R.software.version  = version;
R.software.libs     = ver;
R.code              = {};

% R.analysis.metadata = metadata;
R.analysis.params   = afq.params;
R.analysis.subject  = sub_dirs;

save(fullfile(output_dir,'Reproduce.mat'), 'R');

%% END

if isdeployed
    disp('Sending exit(0) signal.');
    exit(0)
else
    disp('Done!');
end

return
