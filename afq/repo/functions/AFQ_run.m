function [afq, afq_C2ROI] = AFQ_run(sub_dirs, sub_group, afq)
% function [afq patient_data control_data norms abn abnTracts afq_C2ROI] = AFQ_run(sub_dirs, sub_group, afq)
% Run AFQ analysis on a set of subjects to generate Tract Profiles of white
% matter properties.
%
% [afq patient_data control_data norms abn abnTracts] = AFQ_run(sub_dirs,
% sub_group, [afq])
%
% AFQ_run is the main function to run the AFQ analysis pipeline.  Each AFQ
% function is an independent module that can be run on its own.  However
% when AFQ_run is used to analyze data all the proceeding analyses are
% organized into the afq data structure. The AFQ analysis pipeline is
% described in Yeatman J.D., Dougherty R.F., Myall N.J., Wandell B.A.,
% Feldman H.M. (2012). Tract Profiles of White Matter Properties:
% Automating Fiber-Tract Quantification. PLoS One.
%
% Input arguments:
%  sub_dirs  = 1 x N cell array where N is the number of subjects in the
%              study. Each cell should contain the full path to a subjects
%              data directory where there dt6.mat file is.
%
%  sub_group = Binary vector defining each subject's group. 0 for control
%              and 1 for patient.
%
%  afq       = This is a structure that sets up all the parameters for the
%              analysis.  If it is blank AFQ_run will use the default
%              parameters.  See AFQ_Create.
%
% Outputs: 
% afq          = afq structure containing all the results
%
% patient_data = A 1X20 structured array of tract diffusion profiles where
%                data for each tract is in a cell of the structure (eg.
%                patient_data(1) is data for the left thalamic radiation).
%                Each diffusion properties is stored as a different field
%                (eg. patient_data(1).FA is a matrix of FA profiles for the
%                left thalamic radiation). Within the data matrix each
%                subject is a row and each location is a column.  This
%                output variable contains all the data for the patients
%                defined by sub_group ==1.
%
% control_data = The same structure as for patient_data but this contains
%                data for the control subjects defined by sub_group==0.
%
% norms        = Means and standard deviations for each tract diffusion
%                profile calculated based on the control_data.
%
% abn          = A 1 x N vector where N is the number of patients.
%                Each patient that is abnormal on at least one tract is
%                marked with a 1 and each subject that is normal on every
%                tract is marked with a 0. The criteria for abnormal is
%                defined in afq.params.cutoff.  See AFQ create
%
% abnTracts    = An M by N matrix where M is the number of subjects and N
%                is the number of tracts. Each row is a subject and each 
%                column is a tract.  1 means that tract was abnormal for
%                that subject and 0 means it was normal.
%
%  Web resources
%    http://white.stanford.edu/newlm/index.php/AFQ
%
%  Example:
%   
%   % Get the path to the AFQ directories
%   [AFQbase AFQdata] = AFQ_directories;
%   % Create a cell array where each cell is the path to a data directory
%   sub_dirs = {[AFQdata '/patient_01/dti30'], [AFQdata '/patient_02/dti30']...
%   [AFQdata '/patient_03/dti30'], [AFQdata '/control_01/dti30']...
%   [AFQdata '/control_02/dti30'], [AFQdata '/control_03/dti30']};
%   % Create a vector of 0s and 1s defining who is a patient and a control
%   sub_group = [1, 1, 1, 0, 0, 0]; 
%   % Run AFQ in test mode to save time. No inputs are needed to run AFQ 
%   % with the default settings. AFQ_Create builds the afq structure. This
%   % will also be done automatically by AFQ_run if the user does not wish 
%   % to modify any parameters
%   afq = AFQ_Create('run_mode','test', 'sub_dirs', sub_dirs, 'sub_group', sub_group); 
%   [afq patient_data control_data norms abn abnTracts] = AFQ_run(sub_dirs, sub_group, afq)
%
% Copyright Stanford Vista Team, 2011. Written by Jason D. Yeatman,
% Brian A. Wandell and Robert F. Dougherty

%% Check Inputs
if notDefined('sub_dirs') && exist('afq','var') && ~isempty(afq)
    sub_dirs = AFQ_get(afq,'sub_dirs');
elseif notDefined('sub_dirs')
    error('No subject directories');
end
if ~iscell(sub_dirs), sub_dirs = cellstr(sub_dirs); end
if notDefined('sub_group') && exist('afq','var') && ~isempty(afq)
    sub_group = AFQ_get(afq,'sub_group');
elseif notDefined('sub_group')
    error('Must define subject group');
end
if length(sub_group) ~= size(sub_dirs,1) && length(sub_group) ~= size(sub_dirs,2)
    error('Mis-match between subject group description and subject data directories');
end
if ~exist('afq','var') || isempty(afq)
    %if no parameters are defined use the defualts
    afq = AFQ_Create('sub_dirs',sub_dirs,'sub_group',sub_group); 
end
if isempty(afq.sub_group)
    afq = AFQ_set(afq,'sub_group',sub_group);
end
if isempty(afq.sub_dirs)
    afq = AFQ_set(afq,'sub_dirs',sub_dirs);
end
% Check which subjects should be run
runsubs = AFQ_get(afq,'run subjects');
% Define the name of the segmented fiber group
segName = AFQ_get(afq,'segfilename');

%%  Obtain tracts
% for ii = runsubs, do not loop, it is always 1
% Define the current subject to process
afq    = AFQ_set(afq,'current subject',1);
rtpDir = sub_dirs{1};
dtFile = fullfile(rtpDir,'dt6.mat');
[fg_classified, fg_clean, fg, fg_C2ROI,afq] = RTP_TractsGet(dtFile, afq);


% Create new afq for the C2ROI tracts
afq_C2ROI = afq;

% Check the afq, if we have added VOF then there will be a mismatch
% We do not edit ROIs because this is not C2ROI
% C2ROI will have less tracts than the normal ones
if (length(fg_clean) - size(afq.fgnames,2))==6    
    nocleannames = strrep({'L_VOF_clean.tck','R_VOF_clean.tck',...
                           'L_Arcuate_Posterior_clean.tck','R_Arcuate_Posterior_clean.tck',...
                           'L_posteriorArcuate_vot_clean.tck','R_posteriorArcuate_vot_clean.tck'}, ...
                           '_clean.tck','');
    afq.fgnames = [afq.fgnames nocleannames];
end


%% Remove big files
fprintf('[AFQ_run] This is save_output: %s', afq.params.save_output)
if afq.params.save_output
    mrtrixdir = strcat(afq.params.output_dir,'/RTP/mrtrix/');
    files2remove = dir(strcat(mrtrixdir,'ET_fibs-*'));
    for i=1:length(files2remove)
        delete(strcat(mrtrixdir,files2remove(i).name))
    end
end


%% Compute Tract properties
% Load Dt6 File
dt     = dtiLoadDt6(dtFile);
fprintf('\n[AFQ_run] Computing Tract Profiles');
% Determine how much to weight each fiber's contribution to the
% measurement at the tract core. Higher values mean stepper falloff
fWeight = AFQ_get(afq,'fiber weighting');
% By default Tract Profiles of diffusion properties will always be
% calculated
afq.params.clip2rois = false; % will do clip to rois later
[fa,md,rd,ad,cl,vol,TractProfile]=AFQ_ComputeTractProperties(...
                                       fg_clean, ...
                                       dt, ...
                                       afq.params.numberOfNodes, ...
                                       afq.params.clip2rois, ...
                                       sub_dirs{1}, ...
                                       fWeight, ...
                                        afq);


% Parameterize the shape of each fiber group with calculations of
% curvature and torsion at each point and add it to the tract profile
[curv, tors, TractProfile] = AFQ_ParamaterizeTractShape(fg_clean, TractProfile);

% Calculate the volume of each Tract Profile
TractProfile = AFQ_TractProfileVolume(TractProfile);

% Add values to the afq structure
afq = AFQ_set(afq,'vals','subnum',1,'fa',fa,'md',md,'rd',rd,...
   'ad',ad,'cl',cl,'curvature',curv,'torsion',tors,'volume',vol);

% Add Tract Profiles to the afq structure
afq = AFQ_set(afq,'tract profile','subnum',1,TractProfile);

afq_C2ROI.params.clip2rois = true;
%% Now do the same for the afq_C2ROI
[fa,md,rd,ad,cl,vol,TractProfile]=AFQ_ComputeTractProperties(...
                                       fg_C2ROI, ...
                                       dt, ...
                                       afq_C2ROI.params.numberOfNodes, ...
                                       afq_C2ROI.params.clip2rois, ...
                                       sub_dirs{1}, ...
                                       fWeight, ...
                                       afq_C2ROI);


% Parameterize the shape of each fiber group with calculations of
% curvature and torsion at each point and add it to the tract profile
[curv, tors, TractProfile] = AFQ_ParamaterizeTractShape(fg_C2ROI, TractProfile);

% Calculate the volume of each Tract Profile
TractProfile = AFQ_TractProfileVolume(TractProfile);

% Add values to the afq structure
afq_C2ROI = AFQ_set(afq_C2ROI,'vals','subnum',1,'fa',fa,'md',md,'rd',rd,...
   'ad',ad,'cl',cl,'curvature',curv,'torsion',tors,'volume',vol);

% Add Tract Profiles to the afq structure
afq_C2ROI = AFQ_set(afq_C2ROI,'tract profile','subnum',1,TractProfile);


%% Obtain the intersection between the super-fiber and the grey matter
if 0  % maybe make it optional in the future
    fprintf('\n[AFQ_run] Computing intersection between the super-fiber and the grey matter');
    %% Obtain the GM segmentation file
    % Take aparc+aseg, binarize and dilate by one
    aparcaseg     = fullfile(rtpDir,'fs','aparc+aseg.nii.gz');
    segmentation  = fullfile(rtpDir,'segmentation.nii.gz');
    segmentation1 = fullfile(rtpDir,'segmentation_dil-1.nii.gz');
    segmentation2 = fullfile(rtpDir,'segmentation_dil-2.nii.gz');
    cmd  = ['mrcalc -quiet -force ' aparcaseg ' 1000 -gt ' segmentation];
    cmd1 = ['maskfilter -quiet -force -npass 1 ' segmentation ' dilate ' segmentation1];
    cmd2 = ['maskfilter -quiet -force -npass 2 ' segmentation ' dilate ' segmentation2];
    if isfile(aparcaseg)
        cmdr = AFQ_mrtrix_cmd(cmd);
        if cmdr ~= 0; error('\n[AFQ_run] segmentation could not be created, this was the command: %s', cmd);end
        cmdr1 = AFQ_mrtrix_cmd(cmd1);
        if cmdr1 ~= 0; error('\n[AFQ_run] segmentation_dil-1 could not be created, this was the command: %s', cmd1);end
        cmdr2 = AFQ_mrtrix_cmd(cmd2);
        if cmdr2 ~= 0; error('\n[AFQ_run] segmentation_dil-2 could not be created, this was the command: %s', cmd2);end
    end
    
    
    %% Obtener el file con el intersect entre fiber y cortex
    fiberRois = afq.fgnames;
    for fr =1:length(fiberRois)
        fggname = fiberRois{fr};
        fgg     = fg_clean(fr).fibers;
        segm    = niftiRead(segmentation);
        fdImg   = zeros([size(segm.data) length(fgg)]);
        % Extraido de AFQ_RenderFibersOnCortex
        for ii = 1:length(fgg)
            fdImg(:,:,:,ii) = smooth3(dtiComputeFiberDensityNoGUI(...
                                      fgg(ii), ... % Fibras en .mat
                                      segm.qto_xyz, ... % matriz del segmentation.nii.gz
                                      size(segm.data), ... % tamano en voxels
                                      1, ... % = 1, Normalize to 1. =0, fiber count 
                                      [],... % FibreGroupNum: si quieres elegir solo alguna fibra concreta
                                      0), ...% endptFlag=1, solo usar fiber endpoints. LO CAMBIO!!
                               'gaussian', ...
                               5); 
        end

        % Tack on an extra volume that will mark voxels with no fibers
        fdImg      = cat(4,zeros(size(fdImg(:,:,:,1)))+.000001,fdImg);
        % Find the volume with the highest fiber density in each voxel
        [~,fdMax]  = max(fdImg,[],4);
        % Zero out voxels with no fibers
        fdMax      = fdMax-1;
        % Make into a nifti volume
        fdNii      = segm;
        fdNii.data = fdMax;
        segRead = MRIread([dmridir fsp 'segmentation.nii.gz']);
        segRead.vol = permute(fdNii.data, [2 1 3]);  % mierdas de x,y en Matlab
        MRIwrite(segRead, [dmridir fsp strrep(fg.name,' ','_') '_tracts.nii.gz']);
    end
end

if 0 % maintain old code here for reference until solving all the functionalities
    fiberRois = {R_VOF, R_pArc, R_pArc_vot, R_arcuate};
    for fr =1:length(fiberRois)
        fg = fiberRois{fr};
        segmentation = niftiRead(im);
        fdImg = zeros([size(segmentation.data) length(fg)]);
        % Extraido de AFQ_RenderFibersOnCortex
        % Check if the segmentation is binary or is mrVista format
        if length(unique(segmentation.data(:)))>2
            segmentation.data = uint8(segmentation.data==3 | segmentation.data==4);
        end
        for ii = 1:length(fg)
            fdImg(:,:,:,ii) = smooth3(dtiComputeFiberDensityNoGUI(...
                                      fg(ii), ... % Fibras en .mat
                                      segmentation.qto_xyz, ... % matriz del segmentation.nii.gz
                                      size(segmentation.data), ... % tamano en voxels
                                      1, ... % = 1, Normalize to 1. =0, fiber count 
                                      [],... % FibreGroupNum: si quieres elegir solo alguna fibra concreta
                                      0), ...% endptFlag=1, solo usar fiber endpoints. LO CAMBIO!!
                               'gaussian', ...
                               5); 
        end

        % Tack on an extra volume that will mark voxels with no fibers
        fdImg      = cat(4,zeros(size(fdImg(:,:,:,1)))+.000001,fdImg);
        % Find the volume with the highest fiber density in each voxel
        [~,fdMax]  = max(fdImg,[],4);
        % clear fdImg; % Lo inicializo arriba con zeros a ver si arregla el
        % parfor

        % Zero out voxels with no fibers
        fdMax      = fdMax-1;
        % Make into a nifti volume
        fdNii      = segmentation;
        fdNii.data = fdMax;

        % niftiWrite(fdNii, fdNii.fname)

        % Render it
        % [p, msh, lightH] =  AFQ_RenderCorticalSurface(segmentation, ...
        %                         'overlay',fdNii, ...
        %                         'boxfilter',1, ...
        %                         'thresh',[1 20], ...
        %                         'interp','nearest', ...
        %                         'cmap',colormap);


        % Al archivo anterior le he dicho que escriba el nifti con el overlap entre
        % los tractos y la corteza, que esta dada por el archivo de aparc+aseg. 
        % Prueba 1. visualizarlo a ver que tal se ve y ver si podre hacer overlay al
        % espacio individual.
        % Prueba 2. Podria crear ya los ROIs metidos un par de mm hacia dentro, o
        % sea, estaran en volumen, y luego podria salvar los tractos en nifti tb y
        % ver el overlap, luego inflar y buscar el overlap con el white matter...

        % niftiRead-Write y MRIread-write hacen cosas diferentes e inservibles en
        % freeview, aunque en mrview de mrtrix se vieran bien.

        % fdNii.fname = [dmridir fsp fg.name '_overlayGM_vista.nii.gz'];
        % niftiWrite(fdNii, fdNii.fname)

        % No hace falta escribirlo en formato mrVista, ya que estos no se
        % ven vien en freeview, solo se ven bien en mrview de mrtrix, pero
        % los de MRIwrite si he conseguido que se vean igual tanto en uno
        % como en otro.

        % en fs ahora
        segRead = MRIread([dmridir fsp 'segmentation.nii.gz']);
        segRead.vol = permute(fdNii.data, [2 1 3]);  % mierdas de x,y en Matlab
        MRIwrite(segRead, [dmridir fsp strrep(fg.name,' ','_') '_tracts.nii.gz']);
        % MRIwrite(segRead, [dmridir fsp 'NORM_' fg.name '_tracts.nii.gz']);


        % Hay que pensar si hago el paso a la superficie con todos los
        % voxeles que pertenecen a los tractos, o solo me quedo con
        % aquellos voxeles que coinciden con los ROI de interes y luego
        % hago el paso a la superifice. >> He pasado todos los voxeles,
        % luego con aparc podre elegir los voxeles que me interesen para
        % los rois. Lo de los tractos tiene que ser bidireccional. 

        %{
        % Y ahora los convertimos a superficie usando fs
        movname    = fullfile(dmridir, [strrep(fg.name,' ','_') '_tracts.nii.gz']);
        oname      = fullfile(dmridir, [strrep(fg.name,' ','_') '_tracts.mgh']);
        oname305   = fullfile(dmridir, [strrep(fg.name,' ','_') '_tracts305.mgh']);
        % movname    = fullfile(dmridir, ['NORM_' fg.name '_tracts.nii.gz']);
        % oname      = fullfile(dmridir, ['NORM_' fg.name '_tracts.mgh']);
        % oname305   = fullfile(dmridir, ['NORM_' fg.name '_tracts305.mgh']);

        % fshomecajal02 = '/usr/local/freesurfer';
        % fsbincajal02 = '/usr/local/freesurfer/bin';

        % setenv('FREESURFER_HOME', fshome);       
        % Uso --projfrac -1 para meterlo un poco dentro del cortex, si no
        % se ve mucho mas cuarteado. He probado con -2 y -3 pero casi no
        % hay mejora. Al final el problema es que a los gyrus no llegan las
        % fibras.
        cmd2 =  [fsbin fsp 'mri_vol2surf ' ...
                   '--srcsubject '  subname  ' ' ...
                   '--projdist -1 ' ... % '--projfrac 0.5 ' ... %  
                   '--interp trilinear ' ...
                   '--hemi rh ' ...
                   '--regheader '  subname  ' ' ...
                   '--mov '  movname  ' ' ...
                   '--o '  oname ...
                   ];
        cmd3 = [fsbin fsp 'mri_surf2surf ' ...
                   '--srcsubject '  subname  ' ' ...
                   '--srchemi rh ' ...
                   '--srcsurfreg sphere.reg ' ...
                   '--sval '  oname   ' ' ...
                   '--trgsubject fsaverage ' ...
                   '--trghemi rh ' ...
                   '--trgsurfreg sphere.reg ' ...
                   '--tval '  oname305  ' ' ...
                   '--sfmt ' ...
                   '--curv ' ...
                   '--noreshape ' ...
                   '--no-cortex ' ...
                   ];

        system(cmd2);
        system(cmd3);
        %}
    % 
    % 
    % %         cortex = fullfile(dmridir, 'segmentation.nii.gz');
    % %         % overlay = fullfile(AFQdata,'mesh','Left_Arcuate_Endpoints.nii.gz');
    % %         thresh = .01; % Threshold for the overlay image
    % %         crange = [.01 .8]; % Color range of the overlay image
    % %         % Render the cortical surface colored by the arcuate endpoint density 
    % %         [p, msh, lightH] = AFQ_RenderCorticalSurface(cortex, 'overlay' , overlay, 'crange', crange, 'thresh', thresh)
    % % 
    % %         msh = AFQ_meshCreate(cortex, 'color', [.8 .7 .6])
    % %         AFQ_RenderCorticalSurface(msh)
    % % 
    % 
    % 
    % 
    % % 
    % %         %% Ahora voy a ir con la siguiente solucion en mrtrix para freesurfer
    % %         % % If you use the read_mrtrix_tracks.m matlab function you can load
    % %         % .tck files into a matlab structure. Then run a simple loop to keep 
    % %         % the first and last coordinates of each streamline in the .data structure.
    % %         % % The streamline coordinates should be in mm space which you can then 
    % %         % match to freesurfer vertices as follows...
    % %         % % Load a freesurfer surface (e.g. lh.white) into matlab using the 
    % %         % read_surf.m function provided in the set of freesurfer matlab functions. 
    % %         % The vertex_coords variable gives mm coordinates of each vertex. 
    % %         % You can then find the Euclidean distance between an end point and the 
    % %         % vertices to find the nearest vertex for a fiber termination.
    % %         % % Freesurfer then has a bunch of matlab functions to write surface 
    % %         % overlays or annotation files depending on your desired outcome
    % %         % (e.g. save_mgh).
    % %         fname = 'WordHighVsPhaseScrambledWords_Sphere4.tck';
    % %         fname = 'WordHighVsFF_Sphere5.tck';
    % % 
    % % 
    % %         data =  read_mrtrix_tracks(fullfile(dmridir, 'dti90trilin','mrtrix',fname));
    % %         endPoints = zeros(2*length(data.data), 3);
    % %         for ii =1:(2*length(data.data))
    % %             tractNo = ceil(ii/2);
    % %             if mod(ii,2)
    % %                 endPoints(ii,:) = data.data{tractNo}(1,:);
    % %             else
    % %                 endPoints(ii,:) = data.data{tractNo}(end,:);
    % %             end
    % %         end
    % %         WhiteSurf = read_surf(fullfile(fs_SUBJECTS_DIR,subname,'surf','lh.white'));
    % % 
    % %         % Find the index and coordinate of closest vertex
    % %         vertexIndex = knnsearch(WhiteSurf, endPoints);
    % %         vertexPoints = WhiteSurf(knnsearch(WhiteSurf, endPoints),:);
    % % 
    % %         % Write it
    % %         ok = write_label(vertexIndex,[], [], ...
    % %                      fullfile(dmridir, 'dti90trilin','mrtrix',[fname '.label']));
    % 
    % 
    end

end

%% If any other images were supplied calculate a Tract Profile for that
% (planned for 4.3.4)
% parameter
numimages = AFQ_get(afq, 'numimages');
if numimages > 0
   for jj = 1:numimages
       % Read the image file
       image = niftiRead(afq.files.images(jj).path{ii});
       % Check image header
       if ~all(image.qto_xyz(:) == image.sto_xyz(:))
          image = niftiCheckQto(image);
       end  
       % Resample image to match dwi resolution if desired
       if AFQ_get(afq,'imresample')
           image = mrAnatResampleToNifti(image, fullfile(afq.sub_dirs{ii},'bin','b0.nii.gz'),[],[7 7 7 0 0 0]);
       end
       % Compute a Tract Profile for that image
       imagevals = AFQ_ComputeTractProperties(fg_classified, image, afq.params.numberOfNodes, afq.params.clip2rois, sub_dirs{ii}, fWeight, afq);
       % Add values to the afq structure
       afq = AFQ_set(afq,'vals','subnum',ii,afq.files.images(jj).name, imagevals);
       clear imagevals
   end
end

%  % Save each iteration of afq run if an output directory was defined
%  if ~isempty(AFQ_get(afq,'outdir')) && exist(AFQ_get(afq,'outdir'),'dir')
%      if ~isempty(AFQ_get(afq,'outname'))
%          outname = fullfile(AFQ_get(afq,'outdir'),AFQ_get(afq,'outname'));
%      else
%          outname = fullfile(AFQ_get(afq,'outdir'),['afq_' date]);
%      end
%      save(outname,'afq');
%  end

% clear the files that were computed for this subject
clear fg fg_classified TractProfile
% end  % Ends runsubs % It is always 1, remove it, assign ii=1;

return;
