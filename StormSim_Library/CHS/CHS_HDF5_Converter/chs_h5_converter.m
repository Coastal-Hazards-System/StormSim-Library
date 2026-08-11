function [cData] = chs_h5_converter(Filein) %#ok<INUSL>
% This MATLAB function converts any Coastal Hazards System (CHS) Project
% Files and Imports to MATLAB Enviorment

% Variables:
%       Filein= Name of the file to be read, include the .h5 extension
%               Ex. NACCS_TS_SimB_Post0_SP00008_ADCIRC01_Timeseries.h5

%       Filename:  CHS_hdf5_to_matlab_converter.m

%  Written By:  Fabian Garcia-Moreno, USACE-ERDC-CHL, Vicksburg, MS 39180
%  Date:  April 27, 2021
%  Last Modified: 06/02/15

%-----------------------------------------------------------------------------------------------------------------------------
%% DEFINE AUX VARS
% This Is How Versions Are Referenced In HDF5 File
versions_to_look = {'V2','Version_1'};
% This Is How They Are Interpreted In The Script
versions = ["V2","V1"];

%% GET CHS FILE IDENTIFIERS
% Split Filein Path
[~,AA,~] = fileparts(Filein);
% Get CHS Identifiers
A = strsplit(AA,'_');
% region
chs_region = A{1,1};
% Post Processing Type
PostType = A{1,4};
% Get File Type
FileType = A{1,end};
% Storm Type
storm_type = A{1,2};
%-----------------------------------------------------------------------------------------------------------------------------

%% CHECK HDF5 FILE HIERARCHY

% Get HDF5 Internal Structure
info = h5info(Filein);
% Check What Version Of HDF5 File Is
File_version = logical(sum(cell2mat(cellfun(@(x) strcmp({info.Attributes.Name},x)',{'CHS File Format','CHS Data Format'},'un',false)),2));
if ~any(File_version)
    dummystr = '<a href="matlab: web(''https://chswebtool.erdc.dren.mil/'')">here</a>';
    error(['Error: Unrecognized CHS hdf5 storm data file. Please download data from ',dummystr,'']);
end
if sum(File_version)>1 % V2 File Indication
    if contains(FileType,{'AEFcond','AEF'})
        File_version = logical(sum(cell2mat(cellfun(@(x) strcmp({info.Attributes.Name},x)',{'CHS Data Format'},'un',false)),2));
    else
        File_version = logical(sum(cell2mat(cellfun(@(x) strcmp({info.Attributes.Name},x)',{'CHS File Format'},'un',false)),2));
    end
end
File_version = versions(strcmp(info.Attributes(File_version).Value,versions_to_look));
% CHS Timeseries files always use V1 format regardless of header attribute
if strcmp(FileType, 'Timeseries')
    File_version = "V1";
end
% Check If HDF5 File Has Groups
Has_Groups = length(info.Groups)>0; %#ok<*ISMT>
% Check If HDF5 File Has Datasets (Base Level)
Has_Datasets =   length(info.Datasets)>0;
% Check If HDF5 File Has Attributes (Base Level)
Has_Attributes =  length(info.Attributes)>0;

%% CHECK HDF5 GROUPS (IF ANY) INTERNAL HIERARCHY
% If File Is V1 And Has No Group Mark Special Case
if Has_Groups==0
    % Special Case For NLR Files (No Groups)
    v1_special = true;
    % No Attributes Inside Groups
    Has_Gattributes = false;
    % No Datasets Inside Groups
    Has_Gdatasets = false;
    % No Dataset Attributes Inside Groups
    Has_Gdatasets_Attributes = false;
    % If File Is SRR Mark Special Case
    SRR_special = 0;
else
    % Special Case For NLR Files (No Groups)
    v1_special = false;
    % If File Is SRR Mark Special Case
    SRR_special = strcmp(FileType,'SRR');
    % Check If Special SRR Case
    if SRR_special
        % Make All Switches 0
        Has_Gattributes = 0;
        Has_Gdatasets = 0;
        Has_Gdatasets_Attributes = 0;
        Has_Datasets = 0;
    else
        % Check If Groups Have Attributes
        Has_Gattributes =  sum(cell2mat(cellfun(@(x) length(x)>0 ,{info.Groups.Attributes},'un',false)))>0;
        % Check If Groups Have Datasets
        Has_Gdatasets = sum(cell2mat(cellfun(@(x) length(x)>0 ,{info.Groups.Datasets},'un',false)))>0;
        % Check If Groups Have Datasets Attributes
        Has_Gdatasets_Attributes = sum(cell2mat(cellfun(@(x) length(x)>0 ,{info.Groups(1).Datasets.Attributes},'un',false)))>0;
    end
end

%% GET ALL NAMELIST BASED ON CHECKS
%%%% HDF5 BASE LEVEL (info.field) %%%%

%% FIELD: ATTRIBUTES (info.Attributes)
if Has_Attributes
    if File_version == "V1"
        %%%% PROCESS NAME LISTS %%%%
        % Get File Attributes Name List
        FileAttributes = info.Attributes;
        % Define File Attributes To Look For
        FA = {'Save Point ID','Save Point Latitude','Save Point Longitude'};
        % Get Location In HDF5 File Attributes Name List
        FA_indx = logical(sum(cell2mat(cellfun(@(x) strcmp(x,{FileAttributes.Name})',FA,'un',false)),2))';

        %%%% FIND UNITS ROW INDEX %%%%
        % Find Units Location In File Attributes
        FA_units_indx = logical(sum(cell2mat(cellfun(@(x) strcmp(x,{FileAttributes.Name})',{'Latitude Units','Longitude Units'},'un',false)),2))';
        % Extract Units From File Attributes
        FA_units = [{''},{FileAttributes(FA_units_indx).Value}];

        cData.Attributes = FileAttributes;
    else % V2
        %%%% HEADERS & ATTRIBUTES %%%%
        % Get File Attributes Name List
        FileAttributes = info.Attributes;
        % Define File Attributes To Look For
        FA =  {'Save Point ID';'Save Point Latitude';'Save Point Longitude';'Save Point Depth';'Storm Type'};
        % Get Location In HDF5 File Attributes Name List
        FA_indx = cellfun(@(x) find(strcmp(x, {FileAttributes.Name}') == 1), FA, 'un', false)';
        found_mask = ~cellfun(@isempty, FA_indx);
        % Convert str2double for numeric attributes (positions 2-4: Lat, Lon, Depth)
        for ii = 2:4
            if found_mask(ii)
                FileAttributes(FA_indx{ii}).Value = str2double(FileAttributes(FA_indx{ii}).Value);
            end
        end
        FA_indx(~found_mask) = [];
        FA_indx = cell2mat(FA_indx);
        % Add To Output Var
        cData.Attributes = FileAttributes;
        cData.headers = {FileAttributes(FA_indx).Name};

        %%%% FIND UNITS ROW INDEX %%%%
        %  Define File Attributes To Look For
        FA_units_dummy =  {'Latitude Units';'Longitude Units';'Save Point Depth Units'};
        % Get Location In HDF5 File Attributes Name List
        FA_units_indx = logical(sum(cell2mat(cellfun(@(x) strcmp(x,{FileAttributes.Name}'),FA_units_dummy,'un',false)'),2))';
        % Initialize Units Variable
        FA_units = cell(1,length(FA_indx));
        % Assigned Found Units To Storage Var
        FA_units(contains({FileAttributes(FA_indx).Name},{'Lat','Lon','Depth'})) = {FileAttributes(FA_units_indx).Value};
        % Add TO Output Var
        cData.units = FA_units;
    end
else
    FileAttributes = [];
    FA_indx = [];
    FA_units_indx = {};
    FA_units = {};
end

%% FIELD: DATASETS (info.Datasets)

if Has_Datasets
    if File_version=="V2"
        %%%% HEADERS
        % Extract Dataset Info
        FileDatasets = info.Datasets;
        % Search For Storm Props In Datasets
        DS_indx = find(contains({FileDatasets.Name},{'ID','Name','Storm Type'})==1);
        % Extract From Dataset List
        dummy = FileDatasets(DS_indx);
        % Remove From List
        FileDatasets(DS_indx) = [];
        % Add to Top Of List
        FileDatasets = [dummy;FileDatasets];
        % Add To Output Var
        if sum(strcmp('headers',fieldnames(cData)))>0
            cData.headers = [cData.headers,{FileDatasets.Name}];
        else
            cData.headers = {FileDatasets.Name};
        end

        %%%% DESCRIPTIONS
        desc_indx = cellfun(@(x) find(strcmp({x.Name},'Description')==1), {FileDatasets.Attributes}, 'un', false);
        miss_desc = cellfun(@isempty, desc_indx);
        desc_indx(miss_desc) = {1};
        DatasetDescription = cellfun(@(x,y) x(y).Value, {FileDatasets.Attributes}, desc_indx, 'un', false)';
        DatasetDescription(miss_desc) = {''};
        % Assign To Output Var
        dummy = [{FileDatasets.Name}',DatasetDescription];
        cData.Storm_Data_Description = dummy(length(DS_indx)+1:end,:);

        %%%% UNITS
        FDS_units_indx = cellfun(@(x) find(strcmp({x.Name},'Units')==1), {FileDatasets.Attributes}, 'un', false);
        miss_units = cellfun(@isempty, FDS_units_indx);
        FDS_units_indx(miss_units) = {1};
        FDS_units = cellfun(@(x,y) x(y).Value, {FileDatasets.Attributes}, FDS_units_indx, 'un', false);
        FDS_units(miss_units) = {''};
        % Add TO Output Var
        if sum(strcmp('units',fieldnames(cData)))>0
            cData.units = [cData.units,FDS_units];
        else
            cData.units = FDS_units;
        end

    else % V1
        FileDatasets = info.Datasets;
    end
else
    FileDatasets =  {};
end

%% FIELD: GROUPS (info.Groups)
if Has_Groups
    % Get File Groups Name List
    FileGroups = info.Groups;
else
    FileGroups = {};
end

%% FIELD: GROUPS ATTRIBUTES (info.Groups.Attributes)
if Has_Gattributes
    %%%% PROCESS NAME LISTS %%%%
    % Taking First Group As Model For Rest
    GAttributes = info.Groups(1).Attributes;
    % Define Group Attributes To Look For
    GA = {'Save Point Depth';'Storm Name';'Storm ID';'Storm Type';'Storm Group'};
    % Get Location In HDF5 File Attributes Name List
    %%%%%%%%%%                 GA_indx = logical(sum(cell2mat(cellfun(@(x) strcmp(x,{GAttributes.Name}'),GA,'un',false)'),2)');
    GA_indx = cellfun(@(x) find(strcmp(x,{GAttributes.Name}')==1),GA,'un',false)';
    GA_indx(cellfun('isempty',GA_indx)) = [];
    GA_indx = cell2mat(GA_indx);
    %%%%%%%%%%%%%
    %%%% FIND UNITS ROW INDEX %%%%
    % Find Units Location In File Groups Attributes
    GA_units_indx = cell2mat(cellfun(@(x) strcmp(x,{GAttributes.Name}),{'Save Point Depth Units'},'un',false)');
    %                 GA_units = [{GAttributes(GA_units_indx).Value},repmat({''},[1,sum(GA_indx)-1])];
    GA_units = [{GAttributes(GA_units_indx).Value},repmat({''},[1,sum(sum(cell2mat(cellfun(@(x) strcmp(x,{GAttributes.Name}'),GA,'un',false)')))-1])];

else
    GAttributes = {};
    GA_indx = [];
    GA_units_indx =[];
    GA_units = [];
end

%% FIELD: GROUPS DATASETS (info.Groups.Datasets)
if Has_Gdatasets

    %%%% PROCESS NAME LISTS %%%%
    % Taking First Group As Model For Rest
    GDatasets = info.Groups(1).Datasets;
    % Identify yyyymmddHHMM Col In Datasets
    GDS_indx = find(strcmp({GDatasets.Name},'yyyymmddHHMM')==1);
    % Move yyyymmmddHHMM Col
    if ~isempty(GDS_indx) % This Only Applies To V1 Files
        % Reorder Group Dataset Name List
        GDatasets =  [GDatasets(GDS_indx);GDatasets(1:GDS_indx-1);GDatasets(GDS_indx+1:end)];
    end

else
    GDatasets = {};
    GDS_indx = [];
end

%% FIELD: GROUPS DATASETS ATTRIBUTES (info.Groups.Datasets.Attributes)
if Has_Gdatasets_Attributes

    %%%% PROCESS NAME LISTS %%%%
    % Taking First Group As Model For Rest
    GDatasetsAttributes = {GDatasets.Attributes};
    %%%% FIND UNITS ROW INDEX %%%%
    % Find Units Location In Group Datasets Attributes
    GDatasetsAttributes(logical(cell2mat(cellfun(@(x) isempty(x),GDatasetsAttributes,'un',false)))) = {struct('Name','Units','Value','')};
    GDA_units_indx = cell2mat(cellfun(@(x) sum(strcmp('Units',{x.Name})),GDatasetsAttributes,'un',false));
    GDA_units = cell(size(GDatasetsAttributes));

    %% this SECTION CAN BE OPTIMIZED
    for gg = 1:length(GDatasetsAttributes)

        if GDA_units_indx(gg) == 1
            GDA_units(gg) = {GDatasetsAttributes{gg}(find(strcmp({GDatasetsAttributes{gg}.Name},'Units')==1)).Value};
        else
            GDA_units(gg) = {''};
        end
    end
    %%%% EXTRACT UNITS %%%%
    % Extract Units From Groups Datasets Attributes
    %     GDA_units = cellfun(@(x,y) x(y).Value,GDatasetsAttributes,GDA_units_indx,'un',false);
    if (FileType == "AEP" && File_version == "V1")
        % Add AEP Values
        AEP_val = GDatasetsAttributes{1};
        AEP_val = str2double(split(AEP_val(contains({AEP_val.Name},{'AEP'})).Value,','));
        %
        GDA_units = [{'yr^-1'},GDA_units];
    end
else
    GDatasetsAttributes = {};
    GDA_units_indx = [];
    GDA_units = {};
end

%% BUILD DATA HEADERS
if File_version == "V1"
    if (SRR_special==0 && v1_special==0)
        if (FileType == "AEP" && File_version == "V1")
            cData.headers = [{FileAttributes(FA_indx).Name},{GAttributes(GA_indx).Name},{'AEP Values'},{GDatasets.Name}];
        else
            cData.headers = {};
            if Has_Attributes,  cData.headers = [cData.headers, {FileAttributes(FA_indx).Name}]; end
            if Has_Gattributes, cData.headers = [cData.headers, {GAttributes(GA_indx).Name}];    end
            if Has_Gdatasets,   cData.headers = [cData.headers, {GDatasets.Name}];               end
        end

        %% BUILD DATA UNITS HEADERS
        cData.units = [FA_units,GA_units,GDA_units];

        %% EXTRACT DATA FROM HDF5
        %%%% DATA IS STORED IN GROUPS %%%%
        if Has_Groups
            % Initialize Data Storage Var
            data = {};
            %%%% FILE ATTRIBUTES %%%%%
            if Has_Attributes
                % Look For Possible Character Entries
                dummy_indx = logical(cell2mat(cellfun(@(y) strcmp(y,'char'),cellfun(@(x) class(x),{FileAttributes(FA_indx).Value},'un',false),'un',false)));
                % Define Dummy Header
                dummy = {FileAttributes(FA_indx).Value};
                % Conver Characters To Numbers
                dummy(dummy_indx) = num2cell(str2double(dummy(dummy_indx)));
                % Allocate Attributes To Data Matrix (Assuming: SP spatial coords are constant for all storms in dataset)
                data = [data,repmat(dummy,length(FileGroups),1)];
            end
            %%%% GROUPS ATTRIBUTES %%%%
            if Has_Gattributes
                % Find Save Point Depth Location In Group Attributes (Assuming: constant for all storms in dataset)
                dummy_indx = strcmp({GAttributes.Name},'Save Point Depth');
                % Change Save Point Depth To Number
                if sum(dummy_indx)>0
                    GAttributes(dummy_indx).Value = str2double(GAttributes(dummy_indx).Value);
                end
                % Repeate Save Point Depth For All Storms In Dataset
                dummy = repmat({GAttributes(dummy_indx).Value},length(FileGroups),1);
                % If Save Point Depth Was Found Then Add It To Output Var
                if ~isempty(dummy)
                    data = [data,dummy];
                end

            end
            %%%% READ MISSING FIELDS %%%%
            %%%%%%%%%%%                       % Define Group Attributes To Look For
            GA = {GAttributes(GA_indx).Name};
            GA = GA(strcmp('Save Point Depth',GA)==0);
            %%%%%%%                     % Initialize Dummy Storage Vars
            nStorms = length(FileGroups(:,1));
            DScat = cell(nStorms, length(GDatasets));
            GAcat = cell(nStorms, length(GA));
            for stm = 1:nStorms
                % Get Location In HDF5 File Attributes Name List
                GA_indx2 = cellfun(@(x) find(strcmp(x,{FileGroups(stm).Attributes.Name}')==1),GA,'un',false);
                GA_indx2(logical(cell2mat(cellfun(@(x) isempty(x),GA_indx2,'un',false)))) = [];
                % Get Storm Dependant Group Attributes
                GA_dummy = {FileGroups(stm).Attributes(cell2mat(GA_indx2)).Value};

                % Get Storm Group Attributes
                GAcat(stm, :) = GA_dummy;
                % Loop Through ALl Datasets
                for DS = 1:length(GDatasets)
                    % Datasets
                    try
                        if strcmp(GDatasets(DS).Name,'yyyymmddHHMM')
                            raw = h5read(Filein,[info.Groups(stm).Name,'/',GDatasets(DS).Name]);
                            DScat(stm,DS) = {datetime(num2str(raw(:),'%012d'),'InputFormat','yyyyMMddHHmm')};
                        else
                            DScat(stm,DS) = {h5read(Filein,[info.Groups(stm).Name,'/',GDatasets(DS).Name])};
                        end
                    catch % Missing Data Filler
                        if strcmp(GDatasets(DS).Name,'yyyymmddHHMM')
                            DScat(stm,DS) = {NaT};
                        else
                            DScat(stm,DS) = {'NaN'};
                        end
                    end
                    %
                end
            end

            if (FileType == "AEP" && File_version == "V1")
                try
                    % Add To Output Var
                    data = [data,GAcat,{AEP_val},DScat];
                catch
                    data = [data,GAcat,repmat({AEP_val},length(DScat(:,1)),1),DScat];
                end
            else
                % Add To Output Var
                data = [data,GAcat,DScat];
            end
        end % END Has Groups If

    else
        %% SPECIAL CASES
        switch find(strcmp(FileType,{'SRR','NLR'})==1)
            case 1 % SRR
                [data,cData] = chs_h5_special_cases_importer(Filein,info,FA_units,FileDatasets,1);
            case 2 % NLR
                [data,cData] = chs_h5_special_cases_importer(Filein,info,FA_units,FileDatasets,2);
        end
    end % END V1 Special (NLR) or SRR (Special)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% FORMAT EXPORT DATA
    % Store Extracted Data Into Output Data Structure
    cData.StormData = data;
    if sum(strcmp(FileType,{'AEP','AEF','AEFcond'}))==1
        % Expand Cells
        if ~length(data(:,1))>1 % Single entry Hazard Curve
            % Group Attributes
            cData.StormData_Description = info.Groups.Attributes;
            data = expand_aep_cells(data);
            % Store Table Data
            cData.Table_StormData = cell2table(data,'VariableNames',cData.headers);
        else % V2 Hazard Curves (SWL,Hm0, Tp in same file)
            % Repeat cData  for each dataset
            for ll = 2:length(data(:,1))
                cData(ll).Attributes = cData(1).Attributes;
                cData(ll).units = cData(1).units;
                cData(ll).headers = cData(1).headers;
                cData(ll).StormData = cData(1).StormData(ll,:);
            end
            % Remove Extra Entries
            cData(1).StormData = cData(1).StormData(1,:);
            % Loop Through Hazard Curve Files
            for ll = 1:length(data(:,1))
                % Store Table Data
                cData(ll).Table_StormData = cell2table(expand_aep_cells(data(ll,:)),'VariableNames',cData(ll).headers);
                % Group Attributes
                cData(ll).StormData_Description = info.Groups(ll).Attributes;
                % Fix Units
                cData(ll).units(5:end) = repmat({info.Groups(ll).Datasets(3).Attributes(2).Value},1,length(cData(ll).units(5:end)));
            end
        end
    else
        cData.Table_StormData = cell2table(data,'VariableNames',cData.headers);
    end
    %{
                    %
                    cData.StormData_Description = info.Groups.Attributes;
                    % Expand Cells
                    dummy = cell(length(data{end}),length(data));
                    dummy_indx = find(cell2mat(cellfun(@(x) length(x)>1,data,'un',false))==1);
                    dummy_indx2 = find(cell2mat(cellfun(@(x) length(x)==1,data,'un',false))==1);
                    for ii = dummy_indx
                        dummy(:,ii) = num2cell(data{ii});
                    end
                    %
                    dummy(:,dummy_indx2) = repmat(data(dummy_indx2),length(data{end}),1);
                    % Rename
                    data = dummy;
                    cData.Table_StormData = cell2table(data,'VariableNames',cData.headers);
                else
                    cData.Table_StormData = cell2table(data,'VariableNames',cData.headers);
                end
    %}
else % V2
    %% PULL DATA FROM HDF5 V2 FILE
    data = [];
    % Loop Through ALl Datasets
    for DS = 1:length(FileDatasets)
        % Read Datasets
        dummy  = num2cell(h5read(Filein,['/',FileDatasets(DS).Name]));
        data = [data,dummy];
    end
    %%%% ADD DATA FROM ATTRIBUTES IF ANY %%%%
    if Has_Attributes
        try
            data = [repmat({FileAttributes(FA_indx).Value},length(data),1),data];
        catch
            data = [repmat({FileAttributes(FA_indx).Value},length(data(:,1)),1),data];
        end
    end

    %% FORMAT EXPORT DATA V2
    % Store Extracted Data Into Output Data Structure
    cData.StormData = data;
    if sum(strcmp(FileType,{'AEP','AEF','AEFcond'}))==1
        %
        cData.StormData_Description = info.Groups.Attributes;
        data = expand_aep_cells(data);
        cData.Table_StormData = cell2table(data,'VariableNames',cData.headers);
    else
        cData.Table_StormData = cell2table(data,'VariableNames',cData.headers);
    end
end % END V1 or V2 If

%% DEAL WITH LADFALL TIME
if length(cData) == 1
    if any(contains(cData.headers, {'Landfall Time'}))
        % Find Reference Time Header Index
        l_indx = find(strcmp(cData.headers, 'Landfall Time'));
        % Find Peak Time Index
        p_indx = find(strcmp(cData.headers, 'Storm Name'));
        % Grab Reference Time
        ref_time = strsplit(cData.units{l_indx}, {'hrs since ', 'Z'});
        ref_time = datetime(ref_time{2});
        switch FileType
            case 'Peaks'
                % Grab Peak Time
                switch storm_type
                    case {'XH','XC'}
                        total_time = datetime([char(cData.Table_StormData.("Storm Name")), repmat('00', height(cData.Table_StormData), 1)], 'InputFormat', 'yyyyMMddHHmm');
                    otherwise
                        total_time = ref_time+hours(cData.Table_StormData.("Landfall Time"))-hours(cData.Table_StormData.("Peak Time"));
                end
                %
                cData.headers = [cData.headers(1:p_indx), {'yyyymmddHHMM'}, cData.headers(p_indx+1:end)];
                cData.units = [cData.units(1:p_indx), {''}, cData.units(p_indx+1:end)];
                cData.StormData = [cData.StormData(:, 1:p_indx), num2cell(total_time), cData.StormData(:, p_indx+1:end)];
                cData.Table_StormData = [cData.Table_StormData(:, 1:p_indx), table(total_time, 'VariableNames', {'yyyymmddHHMM'}), cData.Table_StormData(:, p_indx+1:end)];
        end
    end

    %% STORM ID Wrong Format
    if any(strcmp(cData.headers, "Storm ID"))
        if ~ischar(cData.Table_StormData.("Storm ID")(1))
            % Get Storm ID Col Index
            col_indx = strcmp('Storm ID', cData.headers);
            % Convert Form Number To Char (Table)
            cData.Table_StormData.("Storm ID") = cellfun(@num2str, cData.StormData(:, col_indx), 'UniformOutput', false);
            % Convert From Number To Char
            cData.StormData(:, col_indx) = cellfun(@num2str, cData.StormData(:, col_indx), 'UniformOutput', false);
        end
    end
end

%% STERIC WATER LEVEL ADJUSTMENTS  + DATUM SHIFT
switch chs_region
    case {'CHS-GLM', 'CHS-GLH'}
        % Steric Adjustment
        [cData] = steric_adjustment(cData, Filein);
        % Datum Adjustment
        [cData] = datum_adjustment(cData, 176.45,Filein);
end
end

%% AUX FUNCTIONS
function [CHS_Data] = datum_adjustment(CHS_Data, datum_shift, Filein)
% Find Row For ADCIRC HDF5 File
ad_bool = contains(Filein, 'ADCIRC');

if any(ad_bool)
    % Get SSL Header Location
    ssl_indx = strcmp(CHS_Data.headers, {'Water Elevation'});
    % Apply Steric Adjustments (StormData)
    CHS_Data.StormData(:, ssl_indx) = cellfun(@(x) x+datum_shift,...
        CHS_Data.StormData(:, ssl_indx), 'un', false);
    % Apply Steric Adjustments (Table_StormData)
    CHS_Data.Table_StormData.('Water Elevation') = cellfun(@(x) x+datum_shift,...
        CHS_Data.Table_StormData.('Water Elevation'), 'un', false);
end
end

function [CHS_Data] = steric_adjustment(CHS_Data, Filein)
% Find Row For ADCIRC HDF5 File
ad_bool = contains(Filein, 'ADCIRC');
if any(ad_bool)
    % Grab Storm Group H5 Keys
    hinfo = h5info(Filein); gNames = {hinfo.Groups.Name}';
    % Get Steric Adjustments
    if ischar(h5readatt(Filein, gNames{1}, 'Steric Adjustment'))
        steric_adj(:, 1) = cellfun(@(x) str2double(h5readatt(Filein, x, 'Steric Adjustment')), gNames, 'un', false);
    else
        steric_adj(:, 1) = cellfun(@(x) h5readatt(Filein, x, 'Steric Adjustment'), gNames, 'un', false);
    end
    % Get SSL Header Location
    ssl_indx = strcmp(CHS_Data.headers, {'Water Elevation'});
    CHS_Data.StormData(:, ssl_indx) = cellfun(@(x, y) x+y,...
        CHS_Data.StormData(:, ssl_indx), steric_adj, 'un', false);
    % Apply Steric Adjustments (Table_StormData)
    CHS_Data.Table_StormData.('Water Elevation') = cellfun(@(x, y) x+y,...
        CHS_Data.Table_StormData.('Water Elevation'), steric_adj, 'un', false);
end
end


function expanded = expand_aep_cells(data_row)
% Expands a 1-x-N cell row where some cols hold vectors and others hold
% scalars into an nRows-x-N cell array ready for cell2table.
n_rows      = length(data_row{end});
n_cols      = length(data_row);
expanded    = cell(n_rows, n_cols);
vec_cols    = cellfun(@(x) length(x) > 1, data_row);
scalar_cols = ~vec_cols;
for ii = find(vec_cols)
    expanded(:, ii) = num2cell(data_row{ii});
end
expanded(:, scalar_cols) = repmat(data_row(scalar_cols), n_rows, 1);
end
