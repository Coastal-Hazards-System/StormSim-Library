function [config, structure] = call_input_parser(input_filename)
%{
    %% DESCRIPTION
    This function parses StormSim's project input file and creates "config"
    data structure. Variable names are controlled by symbols in "str_ref"
    column.
    
    %% INPUTS
    fname: StormSim project input file name.
    
    %% OUTPUTS
    config: MATLAB data structure containing input file data parsed out as
    individual strucutre fields.
    
    %R DEV SIGNATURE
    Developed by: Fabian A. Garcia Moreno ERDC-CHL
%}

%% GRAB AND DEFINE INPUTS
% Define Symbol Column Header (Serves As Anchor Points For Searches)
str_ref = 'Model Variable Symbol';
% Define Anchor Point Offset (Location Of First Data Point)
anchor_offset = 1;
next_tbl_offset = 3;
% Read StormSim Project Input File
input_file = readcell(input_filename);
% Add Filename To Config
config.stormsim_input_file = input_filename;
% Add Gravity Constant
config.gravity_constant = 9.80665; % m/s^2

%% PARSE INPUT FILE AND CREATE CONFIG STRUCTURE
% Find Row And Column Index For "str_ref" In "input_file"
[row_indx,col_indx] = find(cell2mat(cellfun(@(x) strcmp(x,str_ref),input_file,'un',false))==1);
[row_indx2,col_indx2] = find(cell2mat(cellfun(@(x) strcmp(x,'Value'),input_file,'un',false))==1);
% Loop Through Found Instances (Matched Cases Represent Input Tables)
for ii= 1:length(row_indx)
    % Extract Input Table
    if ii == length(row_indx2)
        helper_var = input_file(row_indx(ii)+anchor_offset:end,col_indx(ii):col_indx2(ii));
        helper_var = helper_var(sum(cellfun(@isempty,helper_var),2)<4, :);
    else
        if row_indx(ii+1) == row_indx(1)
            helper_var = input_file(row_indx(ii)+anchor_offset:end,col_indx(ii):col_indx2(ii));
        else
            helper_var = input_file(row_indx(ii)+anchor_offset:row_indx(ii+1)-next_tbl_offset,col_indx(ii):col_indx2(ii));
        end
    end
    % Remove Is Missing
    helper_var = helper_var(~cell2mat(cellfun(@(x) isa(x,'missing'),helper_var(:,1),'UniformOutput',false)),:);
    % Fill Others
    helper_var(cell2mat(cellfun(@(x) isa(x,'missing'),helper_var(:,end),'UniformOutput',false)),end) = {''};
    % Loop Through Input Table Items And Create Config
    for jj = 1:size(helper_var, 1)
        % Create "config" Structure Field
        config.(helper_var{jj,1}) = helper_var{jj,end};
    end
end
% Project Name
project_name = config.project_name;
% Transect Id
struc_id = config.struc_id;
% Case Name
case_name = config.case_name;
% Outfolder
out_folder = config.outfolder;
% Sim Directory
sim_dir = fullfile(out_folder, project_name, struc_id);
% Make Temp Path Empty
config.temp_path = '';
%
if ~ismember(config.workflow, [1,3,4])
    error('Error: config.workflow must be 1 (PROS), 3 (LCS), or 4 (PROS-FB). Value 2 (EVA) was a deprecated alias for 1 and has been removed -- set workflow=1 instead.');
end
switch config.workflow
    case {1,4}
        wflow = 'PROS';
    case 3
        wflow = 'LCS';
end
% OutDir
case_folder = fullfile(out_folder, project_name, struc_id, case_name,wflow);
% Project And Transect ID Folder And Subfolder
if ~exist(case_folder,'dir')
    mkdir(case_folder);
end
% Make Sure Specified File Exist
if ~exist(config.chs_zip, 'file') % Valid Zip Folder Detected
    error('Error: Provided file through config.chs_zip not found. Please verify path...');
end

%% VERIFY IF STORMSIM FILES ALREADY EXIST FOR CURRENT SIMULATION
% Check For StormSim Files On Transect Directory
ss_files_list = dir(fullfile(sim_dir, '*_SP*.mat')); % Search For Expected StormSim Naming Convention On Project Folder
% If Any File Is Found Try Loading To Save Processing Time
if ~isempty(ss_files_list)
    ss_storm = ss_files_list(~contains({ss_files_list.name},{'raw_files'})); % Existing storm .mat created by StormSim
    ss_raw = ss_files_list(contains({ss_files_list.name},{'raw_files'})); % Existing CHS_Data .mat created by StormSim
    % Check For StormSim Processed CHS_Data .mat
    if ~isempty(ss_raw)
        % Load CHS_Data
        load(fullfile(ss_raw.folder, ss_raw.name), 'CHS_Data');
        % Get File Names From Loaded Data Structure
        [file_list_paths, file_list, ~] = ...
            cellfun(@(x) fileparts(x), {CHS_Data.Filename}, 'un', false);
        % Append File Extension
        file_list = cellfun(@(x) [x '.h5'],...
            file_list, 'un', false);
        % Write Out Files On Loaded Data
        config.chs_files_2_convert = [file_list_paths(:), file_list(:)];
        % Grab CHS Study Details
        [config.region, config.sp_ID, config.sp_ID_wave] = get_study_details(file_list);
        % Create String Pattern For Naming Convention
        config.name_prefix = fullfile(sim_dir,...
            [project_name '_' struc_id '_' config.region]);
    else
        config.chs_files_2_convert = cell(0, 2);
    end
    % Check For StormSim Processed storm .mat
    if ~isempty(ss_storm)
        % Load storm
        load(fullfile(ss_storm.folder, ss_storm.name), 'storm', 'prob_mass');
        % Grab Extratropical Storm Fields If Exist
        if isfield(storm,'XC')
            % Grab XC_Nyrs & XC_Nstm
            config.Nyrs_XC = storm.('XC').('Nyrs_XC');
            config.Nstm_XC = storm.('XC').('Nstm_XC');
        end
        if ~isfield(config, 'name_prefix')
            [~,fname,~] = fileparts(ss_storm.name);
            % Try To Find Savepoint ID On Filename
            if contains(fname, {'SP'})
                sp_id = strsplit(fname, {'_', 'SP'});
                config.sp_ID = str2double(sp_id{end});
            else
                % Define Save Point ID As Empty
                config.sp_ID = 1;
            end
            % Try And Find CHS Region On File Name
            if contains(fname, {'CHS-'})
                chs_region = strsplit(fname, '_');
                chs_region = chs_region{contains(chs_region, {'CHS-'})};
                config.region = chs_region;
            else
                config.region = 'Custom_Modeling';% User Needs To Provide Prob Mass
            end
            % Create String Pattern For Naming Convention
            config.name_prefix = fullfile(sim_dir,...
                [project_name '_' struc_id '_' config.region]);
        end
    end
else
    ss_storm = [];
    ss_raw = [];
end
% Get File Extension For "config.chs_zip"
[~,fname, fext] = fileparts(config.chs_zip);
% Get config.chs_zip Data Type
data_case = identify_storm_data_type(config.chs_zip);

%% GRAB CHS_DATA DETAILS
% This code section is executed if user provided a "CHS_Data" type dataset
% through config.chs_zip. This can be a .mat file or .zip folder (with HDF5 files).
if isempty(ss_raw) && strcmp(data_case, 'chs_data')
    switch fext
        case '.mat'
            % Load CHS_Data
            load(config.chs_zip, 'CHS_Data');
            % Get File Names From Loaded Data Structure
            [file_list_paths, file_list, ~] = ...
                cellfun(@(x) fileparts(x), {CHS_Data.Filename}, 'un', false);
            % Append File Extension
            file_list = cellfun(@(x) [x '.h5'],...
                file_list, 'un', false);
            % Write Out Files On Loaded Data
            config.chs_files_2_convert = [file_list_paths(:), file_list(:)];
            % Grab CHS Study Details
            [config.region, config.sp_ID, config.sp_ID_wave] = get_study_details(file_list);
            % Create String Pattern For Naming Convention
            config.name_prefix = fullfile(sim_dir,...
                [project_name '_' struc_id '_' config.region]);
            % Copy File To Add Naming Convention
            copyfile(config.chs_zip, [config.name_prefix '_SP' num2str(config.sp_ID) '_raw_files.mat']);
        case '.zip'
            % Create Temp Folder
            if exist('Temp','dir')==7
                % Determine How Many Temp Dirs Are Present
                temp_list = dir('Temp*');
                % Build Temp Folder Name
                config.temp_path = ['Temp_' num2str(length(temp_list) + 1)];
                % Assign Variable For Convenience
                temp_path = config.temp_path;
                % Create Temp Folder
                mkdir(temp_path);
            else % Temp Does Not Exist
                config.temp_path = 'Temp';
                temp_path = config.temp_path;
                mkdir('Temp');
            end
            % Decompress Zip Folder
            unzip(config.chs_zip,temp_path);
            % Scan Unzip Directory
            temp_dir = dir([temp_path filesep '**' filesep '*.h5']);
            % Add Field To config
            config.chs_files_2_convert = sortrows([{temp_dir.folder}', {temp_dir.name}'],2,'ascend');
            % Grab ADCIRC Reference File
            CHS_file_ref = config.chs_files_2_convert(contains(config.chs_files_2_convert(:,2), {'ADCIRC'}), :);
            % Try And Find SP Depth On HDF5 Attributes
            try
                % Get H5 Info
                sp_depth = h5info(fullfile(CHS_file_ref{1, 1}, CHS_file_ref{1, 2}));
                % Need To Access Attributes Of First Storm
                sp_depth = sp_depth.Groups.Attributes;
                % Grab Save Point Depth
                config.chs_sp_depth = str2double(sp_depth(strcmp({sp_depth.Name},{'Save Point Depth'})).Value);
            catch
                disp('Warning: could not find ADCIRC savepoint depth on h5 attributes. Using value on config file....');
            end
            % Grab File List To Extract Study Details From Naming
            file_list = config.chs_files_2_convert(:,2);
            % Grab CHS Study Details
            [config.region, config.sp_ID, config.sp_ID_wave] = get_study_details(file_list);
            % Create String Pattern For Naming Convention
            config.name_prefix = fullfile(sim_dir,...
                [project_name '_' struc_id '_' config.region]);
    end
end

%% GRAB STORM DETAILS
% This code section is executed if user provided a "storm" type dataset
% through config.chs_zip. "storm" meaning a dataset containing surge and
% wave data for each event matched in time.
if isempty(ss_storm) && strcmp(data_case, 'storm_data')
    % Add CHS Files 2 Convert In Cell Array
    config.chs_files_2_convert = cell(0, 2);
    % Try To Find Savepoint ID On Filename
    if contains(fname, {'SP'})
        sp_id = strsplit(fname, {'_'});
        sp_id = sp_id{contains(sp_id, {'SP'})};
        sp_id = str2double(strrep(sp_id,'SP',''));
        config.sp_ID = sp_id;
    else
        % Define Save Point ID As Empty
        config.sp_ID = 1;
    end
    config.sp_ID_wave = []; % Not important
    % Try And Find CHS Region On File Name
    if contains(fname, {'CHS-'})
        chs_region = strsplit(fname, '_');
        chs_region = chs_region{contains(chs_region, {'CHS-'})};
        config.region = chs_region;
    else
        chs_region = 'Custom_Modeling';
        config.region = 'Custom_Modeling';% User Needs To Provide Prob Mass
    end
    % Load storm & prob_mass From Provided .mat
    load(config.chs_zip, 'storm', 'prob_mass');
    % Validate "storm" dataset
    storm_validation(config, storm);
    % Grab Extratropical Storm Fields If Exist
    if isfield(storm,'XC')
        % Grab XC_Nyrs & XC_Nstm
        config.Nyrs_XC = storm.('XC').('Nyrs_XC');
        config.Nstm_XC = storm.('XC').('Nstm_XC');
    end
    % Validate prob_mass Based On Storm Content
    if isfield(storm, 'TC')
        prob_mass_validation(config, prob_mass, storm);
    end
    % Create String Pattern For Naming Convention
    config.name_prefix = fullfile(sim_dir,...
        [project_name '_' struc_id '_' chs_region]);
    % Create StormSim storm file
    save([config.name_prefix '_SP' num2str(config.sp_ID) '.mat'], 'storm', 'prob_mass');
end

%% APPLY STRUCTURE TYPE RESPONSES RESTRICTIONS
% Grab Structure Response Switches
switch config.struc_type
    case 1 % Levee
        config.compute_dn50_seaside = 0;
        config.compute_dn50_leeside = 0;
        config.compute_dn50_lcbw = 0;
        config.compute_dn50_submerged = 0;
        config.compute_p1 = 0;
        config.compute_p2_p3 = 0;
        config.compute_nappe = 0;
    case 2 % Floodwall
        config.compute_dn50_seaside = 0;
        config.compute_dn50_leeside = 0;
        config.compute_dn50_lcbw = 0;
        config.compute_dn50_submerged = 0;
        config.compute_r2p = 0;
        % Enforce Dependencies For P2/P3 Computations
        if config.compute_p2_p3 == 1
            config.compute_p1 = 1;
            % Secondary Responses Require Forcing HCs 
            config.pros_compute_forcing_HC = 1;
        end
        % Enforce Dependencies For Nappe Discharge Computations
        if config.compute_nappe == 1
            config.compute_q = 1;
            config.pros_compute_forcing_HC = 1;
        end
    case 3 % Rubble Mound
        config.compute_dn50_lcbw = 0;
        config.compute_p1 = 0;
        config.compute_p2_p3 = 0;
        config.compute_nappe = 0;
    case 4 % Low Crested Break Water
        config.compute_dn50_seaside = 0;
        config.compute_dn50_leeside = 0;
        config.compute_dn50_submerged = 0;
        config.compute_p1 = 0;
        config.compute_p2_p3 = 0;
        config.compute_nappe = 0;
end

%% APPEND ADDITIONAL SIMULATION DETAILS TO CONFIG
if ~isfield(config, 'Nyrs_XC')
    config.Nyrs_XC = 0;
end
% Make Sure Confidence Limits Are In The Expected Format
try
    % Split Sring
    dummy = strsplit(config.project_CLs,{' ','[',']'});
    dummy = dummy(2:end-1);
    % Sort CLs
    dummy = sort(cellfun(@str2double, dummy), "ascend");
    % Store Back On Config
    config.project_CLs = ['[',strtrim(sprintf('%d ', dummy)),']'];
catch % In Case Of Unexpected Format , Default To
    config.project_CLs = '[16 84]';
end
% Deprecated Or Hidden Features
config.structure_dir = 0; % Assume Shore Normal Waves
config.chs_wDir_u_a = 0; % Assume Shore Normal Waves
config.tide_std = 0; % Tidal std , not implemented
% This helps toggle print outs
config.print_progress = true;
% Hide Berms Until Conceptual Models Are Set
switch config.struc_type
    case {1,3} % Levee, Rubblemounds
        config.add_toe_berm = 0;
        config.berm_seaward_slope = 1;
        config.berm_crest_width = 0;
        config.berm_crest_elevation = 0;
end

%% RESPONSES UNCERTAINTIES
uData = readcell('primary_responses_epistemic_uncertainties.txt');
uData(1, :) = []; % Remove Headers
uData = cell2struct(uData(:,3), uData(:,1));
config.dn50_u = uData.dn50_u;
config.p1_u = uData.p1_u;
config.q_u = uData.q_u;
config.r2p_u = uData.r2p_u;

%% LOAD COMPUTATIONAL ENVIRONMENT
% isempty(ss_files_list) -> 1 (Print Welcome Message) , 0 (No Print)
% Set-up Computational Environment
[config, structure] = call_environment_setup(config, isempty(ss_files_list));

%% AUX FUNCTIONS
% Function 1: Extracts CHS study Details Needed For StormSim Simulation
    function [region, sp_ID, sp_ID_wave] = get_study_details(files_in)
        % ADCIRC Indx
        ad_indx = contains(files_in,'ADCIRC');
        % ADCIRC Reference File
        ad_ref = files_in(ad_indx); ad_ref = ad_ref(1); % Keep 1 File Only
        % Wave Reference File
        wave_ref = files_in(~ad_indx); wave_ref = wave_ref(1); % Keep 1 File Only
        % Split Into Identifiers
        chs_ident = cellfun(@(x) strsplit(x, '_'), [ad_ref;wave_ref], 'un', false);
        % Store CHS Region
        region = chs_ident{1}{1};
        % Store ADCIRC SP ID
        sp_ID = str2double(chs_ident{1}{5}(3:end));
        % Add CHS Wave SP ID
        sp_ID_wave = str2double(chs_ident{2}{5}(3:end));
    end
% Function 2: Identify What Type Of Modeling Data Is Provided By User
    function data_case = identify_storm_data_type(chs_zip)
        % Get File Extension
        [~, ~, file_extension] = fileparts(chs_zip);
        % Determine Modeling Data Provided Through config.chs_zip
        switch file_extension
            case '.mat' % Option 1: mat file with "storm" & "prob_mass" | Option 2: mat file with "CHS_Data"
                data_case = {'chs_data', 'storm_data'};
                % Verify Variable Inside .mat File
                mf = matfile(chs_zip);
                vars = who(mf);
                % Make Sure We Only Allow For Supported Vars
                var_pass = contains({'CHS_Data','storm'}, vars);
                %
                if sum(var_pass) == 0 || sum(var_pass) >1
                    error('Error: Provided .mat file under chs_zip must have "CHS_Data" or "storm" variables (not both).')
                else
                    data_case = data_case{var_pass};
                end
                % For storm_data: require prob_mass variable to also be present
                if strcmp(data_case, 'storm_data') && ~any(contains(vars, 'prob_mass'))
                    error('Error: storm_data .mat must contain both "storm" and "prob_mass" variables.');
                end
            case '.zip' % Zip Folder Downloaded From CHS
                data_case = 'chs_data';
            otherwise
                error('Error: Unsuported file type for config.chs_zip. Please provide valid .mat file or CHS .zip folder')
        end
    end
end % End of Function
