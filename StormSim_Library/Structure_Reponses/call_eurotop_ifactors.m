function gammas = call_eurotop_ifactors(config, structure, SWL, Hm0)
%% GRAB DETAILS FROM "config"
strucType = config.struc_type;
% Surface roughness coefficient
gamma_f = structure.roughness_ifactor;
% Get Berm Logical Flag
add_berm = config.add_toe_berm;

%% GRAB DETAILS FROM "structure"
% Crest Elevation
crest_ele = structure.crest_elevation;
% Toe Elevation
toe_ele = structure.toe_elevation;
if strucType == 2
    % Wall Bottom Elevation
    wall_bottom_elev = structure.wall_bottom_elevation;
else
    wall_bottom_elev = structure.toe_elevation;
end
% Seaward Slope
% seaward_slope = structure.seaside_slope;
% Compute Freeboard
Rc = crest_ele - SWL;

if add_berm
    % Berm Elevation (<0 Below Datum Zero)
    berm_elev = structure.berm_elevation; %
    % Berm Width
    berm_width = structure.berm_width;
    % Berm Slope
    berm_slope = structure.berm_slope;
else
    % Berm Elevation (<0 Below Datum Zero)
    berm_elev = toe_ele; % This Translates to h == hb
    % Berm Width
    berm_width = 0;
    % Berm Slope
    berm_slope = 1;  % Can't set to 0, Will cause 1/0 in Goda Pressure Calcs
end


%% COMPUTE INFLUENCE FACTORS
% Wall Influence Factor
[gammas.gamma_v, gammas.gamma_star] = wall_influence_factor(crest_ele,wall_bottom_elev,Rc,strucType);
% Surface roughness Influence Factor
gammas.gamma_f = surface_roughness_influence_factor(gamma_f, Hm0);
% Oblique wave coefficients - Not implemented in StormSim as of 9/03/20
[gammas.gamma_beta_r2p, gammas.gamma_beta_q] = oblique_waves_influence_factor(size(Hm0));
% Berm Influence Factor (Not used)
if add_berm == 1
    [gammas.gamma_b] = berm_influence_factor(berm_width, berm_elev, Hm0, SWL, berm_slope);
else
    gammas.gamma_b = ones(size(Hm0));
end
end