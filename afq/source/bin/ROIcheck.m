function A = ROIcheck(csv_file, J)
%% Read the tractparams.csv and validate
% TODO: shorten this script creating independent functions, for example,ROIsCheck
fprintf('[RTP] Trying to read tractparams file %s\n', csv_file);
A = readtable(csv_file, 'FileType', 'text', ...
                        'Delimiter','comma', ...
                        'ReadVariableNames',true,...
                        'TextType', 'string');
disp('[RTP] Showing contents of params.csv file:')
A
disp('[RTP] Checking there are the required variables, and that the tract names are correct')

varsShouldBe = {'roi1' 'extroi1' 'roi2' 'extroi2' ...
                'roi3' 'extroi3'  'roi4' 'extroi4' ...
                'roiexc1' 'extroiexc1'  'roiexc2' 'extroiexc2' ...
                'dilroi1' 'dilroi2' 'dilroi3' ...
                'dilroi4' 'dilroiexc1' 'dilroiexc2' ...
                'evaluation' 'bidir' 'label' 'fgnum' 'hemi' 'slabel' 'shemi' ...
                'nhlabel' 'wbt' 'usecortex' 'tckmaxlen' 'tckminlen' ...
                'tckangle' 'algorithm' ...
                'select' 'cutoff' 'maxDist' 'maxLen' 'numNodes' 'meanmed' 'maxIter'};
varsAre = A.Properties.VariableNames;
if ~isequal(varsShouldBe,varsAre)
    disp('[RTP] The variable names or the number of variables in tractparams.csv is not correct.')
    disp('[RTP] The variables should be:')
    varsShouldBe
    error('[RTP] Ending the RTP-Pipeline')
end
% Check tract names:
A.label = strrep(A.label,'-','_');
A.label = strrep(A.label,'&','_');
A.label = strrep(A.label,'$','_');
A.label = strrep(A.label,'%','_');
A.label = strrep(A.label,'(','_');
A.label = strrep(A.label,')','_');

A.slabel = strrep(A.slabel,'-','_');
A.slabel = strrep(A.slabel,'&','_');
A.slabel = strrep(A.slabel,'$','_');
A.slabel = strrep(A.slabel,'%','_');
A.slabel = strrep(A.slabel,'(','_');
A.slabel = strrep(A.slabel,')','_');

% Check that all short track names are unique
if ~isequal(size(unique(A.slabel),1),height(A))
	error('All tract short names (slabel) should be unique.')
end



for dr = height(A):-1:1
    delete_row = false;    
    B = A(dr,:);
    % Check that all ROIs are available in the fs/ROIs folder, if not, throw error.
    % Create list of all ROIs
    checkTheseRois = [strcat(B.roi1,B.extroi1);strcat(B.roi2,B.extroi2);strcat(B.roi3,B.extroi3); ...
                      strcat(B.roi4,B.extroi4);strcat(B.roiexc1,B.extroiexc1);strcat(B.roiexc2,B.extroiexc2)];
    % If there is an AND, this means that there are two ROIs
    % Create a new list with the individual ROIs to create, after checking the individuals are there
    createROInew = [];
    %createROI1   = [];
    createROI   = {};
    for nc=1:length(checkTheseRois)
        rname = checkTheseRois(nc);
        if strcmp(rname,"NO.nii.gz")
            % do nothing
        elseif contains(rname,'_AND_')
            % Add the ROI to be created
            createROInew = [createROInew; rname];
            % Check if the individuals exist
            rois12 = strsplit(rname,'_AND_');
            subROI = [];
            for sr=1:length(rois12)
                if sr < length(rois12)
                    % ROI1
                    rpath  = fullfile(J.params.roi_dir,strcat(rois12{sr},".nii.gz"));
                    if ~isfile(rpath);error('ROI %s is required and it is not in the ROIs folder',rpath);end
                    subROI = [subROI; strcat(rois12{sr},".nii.gz")];
                elseif sr == length(rois12)
                    % ROI2
                    rpath  = fullfile(J.params.roi_dir,rois12{sr});
                    if ~isfile(rpath);error('ROI %s is required and it is not in the ROIs folder',rpath);end
                    subROI = [subROI; string(rois12{sr})];
                end
            end
            createROI{end+1} = subROI;
        else
            rpath  = fullfile(J.params.roi_dir,rname);
            if ~isfile(rpath);error('ROI %s is required and it is not in the ROIs folder',rpath);
            else
                R = niftiRead(char(rpath));
                if sum(R.data(:))==0
                    warning('ROI %s is empty, check it please',rpath);
                    delete_row = true;
                end
            end

        end
    end

    % Create the ROIs by concatenating. Use Matlab for now
    for nt=1:length(createROInew)
        nroi = fullfile(J.params.roi_dir,createROInew(nt));
        if ~isfile(nroi)
            % Read the first existing ROIs
            roi1 = fullfile(J.params.roi_dir,createROI{nt}{1});
            R1 = niftiRead(char(roi1));
            nR   = R1;
            nR.fname = char(nroi);

            for st=2:length(createROI{nt})
                roi2 = fullfile(J.params.roi_dir,createROI{nt}{st});
                % Read the rest existing ROIs
                R2   = niftiRead(char(roi2));
                % Create the new file and concatenate the data
                nR.data  = uint8(nR.data | R2.data);
            end
            niftiWrite(nR);
        end
    end
    % if anyone of the ROIs is empty, delete the whole row
    if delete_row == true
    A(dr, :) = [];
    end
end


% Dilate those ROIs that require it using mrtrix's tool maskfilter
% maskfilter input filter(dilate) output
for nl=1:height(A)
	% Check line by line and create the dilated ROIs.
	ts = A(nl,:);
	if ts.dilroi1>0
		inroi  = char(fullfile(J.params.roi_dir, strcat(ts.roi1,ts.extroi1)));
		outroi = char(fullfile(J.params.roi_dir, strcat(ts.roi1,'_dil-',num2str(ts.dilroi1),ts.extroi1)));
		cmd    = ['maskfilter -quiet -force -npass ' num2str(ts.dilroi1)  ' ' inroi  ' dilate - | '...
				  'mrthreshold -force -abs 0.5 - ' outroi];
		if isfile(outroi)
			disp('ROI exist, not recreating')
		else
			cmdr   = AFQ_mrtrix_cmd(cmd);
			if cmdr ~= 0
				error('[RTP] ROI could not be created, this was the command: %s', cmd)
			end
		end
	end
	if ts.dilroi2>0
		inroi  = char(fullfile(J.params.roi_dir, strcat(ts.roi2,ts.extroi2)));
		outroi = char(fullfile(J.params.roi_dir, strcat(ts.roi2,'_dil-',num2str(ts.dilroi2),ts.extroi2)));
		cmd    = ['maskfilter -quiet -force -npass ' num2str(ts.dilroi2)  ' ' inroi  ' dilate - | '...
				  'mrthreshold -force -abs 0.5 - ' outroi];
		if isfile(outroi)
			disp('ROI exist, not recreating')
		else
			cmdr   = AFQ_mrtrix_cmd(cmd);
			if cmdr ~= 0
				error('[RTP] ROI could not be created, this was the command: %s', cmd)
			end
		end
	end
	if ts.dilroi3>0 && ~strcmp(ts.roi3,"NO")
		inroi  = char(fullfile(J.params.roi_dir, strcat(ts.roi3,ts.extroi3)));
		outroi = char(fullfile(J.params.roi_dir, strcat(ts.roi3,'_dil-',num2str(ts.dilroi3),ts.extroi3)));
		cmd    = ['maskfilter -quiet -force -npass ' num2str(ts.dilroi3)  ' ' inroi  ' dilate - | '...
				  'mrthreshold -force -abs 0.5 - ' outroi];
		if isfile(outroi)
			disp('ROI exist, not recreating')
		else
			cmdr   = AFQ_mrtrix_cmd(cmd);
			if cmdr ~= 0
				error('[RTP] ROI could not be created, this was the command: %s', cmd)
			end
		end
	end
	if ts.dilroi4>0 && ~strcmp(ts.roi4,"NO")
		inroi  = char(fullfile(J.params.roi_dir, strcat(ts.roi4,ts.extroi4)));
		outroi = char(fullfile(J.params.roi_dir, strcat(ts.roi4,'_dil-',num2str(ts.dilroi4),ts.extroi4)));
		cmd    = ['maskfilter -quiet -force -npass ' num2str(ts.dilroi4)  ' ' inroi  ' dilate - | '...
				  'mrthreshold -force -abs 0.5 - ' outroi];
		if isfile(outroi)
			disp('ROI exist, not recreating')
		else
			cmdr   = AFQ_mrtrix_cmd(cmd);
			if cmdr ~= 0
				error('[RTP] ROI could not be created, this was the command: %s', cmd)
			end
		end
    end
	if ts.dilroiexc1>0 && ~strcmp(ts.roiexc1,"NO")
		inroi  = char(fullfile(J.params.roi_dir, strcat(ts.roiexc1,ts.extroiexc1)));
		outroi = char(fullfile(J.params.roi_dir, ...
                      strcat(ts.roiexc1,'_dil-',num2str(ts.dilroiexc1),ts.extroiexc1)));
		cmd    = ['maskfilter -quiet -force -npass ' num2str(ts.dilroiexc1)  ' ' inroi  ' dilate - | '...
				  'mrthreshold -force -abs 0.5 - ' outroi];
		if isfile(outroi)
			disp('ROI exist, not recreating')
		else
			cmdr   = AFQ_mrtrix_cmd(cmd);
			if cmdr ~= 0
				error('[RTP] ROI could not be created, this was the command: %s', cmd)
			end
		end
    end
	if ts.dilroiexc2>0 && ~strcmp(ts.roiexc2,"NO")
		inroi  = char(fullfile(J.params.roi_dir, strcat(ts.roiexc2,ts.extroiexc2)));
		outroi = char(fullfile(J.params.roi_dir, strcat(ts.roiexc2,'_dil-',num2str(ts.dilroiexc2),ts.extroiexc2)));
		cmd    = ['maskfilter -quiet -force -npass ' num2str(ts.dilroiexc2)  ' ' inroi  ' dilate - | '...
				  'mrthreshold -force -abs 0.5 - ' outroi];
		if isfile(outroi)
			disp('ROI exist, not recreating')
		else
			cmdr   = AFQ_mrtrix_cmd(cmd);
			if cmdr ~= 0
				error('[RTP] ROI could not be created, this was the command: %s', cmd)
			end
		end
	end
end
% FINISHED ROI CHECK AND CREATION
