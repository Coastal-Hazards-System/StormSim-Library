function [structure] = create_structure_geometry(config, show_plot)
%{
    %% DESCRIPTION
        This function creates MATLAB struture object containing project structure geometry.
    
    %% INPUTS
        config: Parsed CAST input file. | struc | 1 x number_of_inputs
        Required fields are listed below:
            config.
                   crest_elevation: Structure crest elevation
                   crest_width: Strucutre crest width.
                   seaside slope: Structure seaward slope.
                   leeside slope: Strucutre landward slope.
                   toe_elevation: Structure toe elevation (Nevative below datum zero)
    
    %% OUTPUTS
        structure: Formatted structure geometry details | struc | 1 x varies_per_struc_type
            structure.
         ------- All Structure Types Fields -------
                   crest_elevation: Structure crest elevation
                   crest_width: Structure crest width.
                   toe_elevation: Structure toe elevation (Negative below datum zero)
                   sp_depth: CHS savepoint depth.
  
        ------- Rubblemound & Levee Only Fields -------
                   seaside_slope: Structure seaward slope.
                   leeside_slope: Structure landward slope.
    
            ------- Rubblemound Only Fields -------
                   armor_delta: Armor stone immersed relative density. (1-rho_s/rho_h20)
                   seaside_limit_S: Rubblemound structure seaward face damage limit (S).
                   cem_P: Mean permeability coefficient (From CEM).
    
              --- StormSim: MCS/CSR Only Fields ---
                   water_density: Water Density.
                   seaside_mass: Rubblemound structure seaward face stone mass.
                   seaside_init_S: Structure seaward face damage initiation limit (S).
                   leeside_mass: Rubblemound structure landward face stone mass.
                   leeside_init_S: Structure landward face damage initiation limit (S).
                   leeside_limit_S: Rubblemound structure landward face damage limit (S).
   
 %% DEV SIGNATURE
    Developed by: Fabian A. Garcia Moreno ERDC-CHL
%}
%% GRAB INPUT FROM "config"
%{
        This section meant to provide an easy way to make changes to config
        variable calls without having to alter core code.
%}
% Structure Type
struc_type = config.struc_type;

%% DEFINE VARIBALES TO GRAB FROM CONFIG PER STRUCTURE TYPE & WORKFLOW
% Evaluate Case Per Structure Type
switch struc_type
    case 1 % Levee
        % Define Structure Type String
        s_type = 'levee';
        % Define "config" Vars To Grab
        vars_2_grab = {'crest_elevation','crest_width','toe_elevation','seaside_slope',...
            'leeside_slope','berm_crest_width','berm_crest_elevation',...
            'water_density','roughness_ifactor', 'berm_seaward_slope','berm_toe_elevation','offshore_slope'};
    case 2 % Floodwall
        % Define Structure Type String
        s_type = 'floodwall';
        % Define "config" Vars To Grab
        vars_2_grab = {'crest_elevation','crest_width','toe_elevation',...
            'structure_dir','berm_crest_width','berm_crest_elevation',...
            'water_density','roughness_ifactor', 'berm_seaward_slope', 'wall_bottom_elevation','offshore_slope'};
    case 3 % Rubblemound
        % Define Structure Type String
        s_type = 'rubblemound';
        % Define Vars To Grab
        vars_2_grab = {'crest_elevation','crest_width','toe_elevation','seaside_slope',...
            'leeside_slope','berm_crest_width','berm_crest_elevation','berm_seaward_slope',...
            'armor_delta','seaside_mass','leeside_mass','water_density','cem_P',...
            'seaside_design_S','leeside_design_S',...
            'roughness_ifactor', 'seaside_S_uls', 'leeside_S_uls','offshore_slope'};
    case 4 % LCBW 
                % Define Structure Type String
        s_type = 'lowcrestedbw';
        % Define Vars To Grab
        vars_2_grab = {'crest_width','toe_elevation','seaside_slope',...
            'leeside_slope','berm_crest_width','berm_crest_elevation','berm_seaward_slope',...
            'armor_delta','crest_elevation','seaside_mass','water_density','offshore_slope'};
end

% Temp Patch (Remove Berm Fields)
if config.add_berm == 0
    vars_2_grab(contains(vars_2_grab, 'berm')) = [];
end

%% EXTRACT AND FORMAT "config" DATA
% Display Status Message
disp(['Creating ',s_type,' geometry....']);
% Loop Through All Variables
for ii = 1:length(vars_2_grab)
    % Extract Data And Store On Structure Variable
    structure.(vars_2_grab{ii}) = config.(vars_2_grab{ii});
end

%% CREATE CROSS_SECTION PLOT
% Show/Close Figure According To User
if show_plot == 1
    % Create Figure
    fig = plot_structure_geometry(config, structure);
    fig.Visible = 'On';
else
    fig = plot_structure_geometry(config, structure);
    close(fig);
end
end

