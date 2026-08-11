function [Resp] = compute_structure_response(config, structure, project_forcing,  emp_coeff, get_max)
%% GRAB DETAILS FROM "config"
% Strucutre Type
struc_type = config.struc_type;
% Storm Duration [s]
duration = config.storm_duration*24*3600; % Convert day to s
% Define Requested Workflow
workflow = config.workflow;
% Gravity
g = config.gravity_constant;
% Grab Structure Response Switches
calc_dn50_ss = config.compute_dn50_seaside;
calc_dn50_ls = config.compute_dn50_leeside;
calc_dn50_lcbw = config.compute_dn50_lcbw;
calc_r2p = config.compute_r2p;
calc_q = config.compute_q;
calc_q_vol = config.compute_q_vol; % Permanently set to 0 for FB
calc_dd = config.compute_damaging_depth;
calc_dd_ks = config.compute_damaging_depth_Ks;
calc_p1 = config.compute_p1;
calc_p2_p3 = config.compute_p2_p3;
calc_nappe = config.compute_nappe;
calc_wave_transmission = config.compute_wave_transmission;
calc_dn50_submerged = config.compute_dn50_submerged;
% Get Save Point Depth
SPdepth = config.chs_sp_depth;
% Remove Responses Based On Structure Type
switch struc_type
    case 1 % Levee (R2p & OT)
        calc_p1 = 0;
        calc_dn50_ss = 0;
        calc_dn50_ls = 0;
        calc_dn50_lcbw = 0;
    case 2 % Floodwall (q, P1, P2, P3, Nappe)
        calc_dn50_ss = 0;                  
        calc_dn50_ls = 0;
        calc_dn50_lcbw = 0;
        calc_r2p = 0;
        if calc_p2_p3 == 1
            calc_p1 = 1;
        end
        if calc_nappe == 1
            calc_q = 1;
        end
    case 3 % Rubblemound (R2p, q, Dn50)
        calc_p1 = 0;
        calc_dn50_lcbw = 0;
    case 4  % LCBW
        calc_p1 = 0;
        calc_dn50_ss = 0;
        calc_dn50_ls = 0;
end
% No Structural Response Computed
no_resp = sum([calc_dn50_ss,calc_dn50_ls,calc_dn50_lcbw,calc_r2p,calc_q,calc_q_vol,calc_p1,calc_dd]);

%% GRAB DETAILS FROM "structure"
% Define Structure Crest Elevation
crest_elev = structure.crest_elevation;
% Define Structure Crest Width
crest_width = structure.crest_width;
% Define Structure Toe Elevation (<0 below datum zero)
toe_elev = abs(structure.toe_elevation); % Flip convention
if config.add_toe_berm
    % Berm Elevation (<0 Below Datum Zero)
    berm_elev = abs(structure.berm_crest_elevation); %
    % Berm Width
    berm_width = structure.berm_crest_width;
    % Berm Slope
    berm_slope_tana = 1./structure.berm_seaward_slope;
else
    % Berm Elevation (<0 Below Datum Zero)
    berm_elev = abs(toe_elev); % This Translates to h == hb
    % Berm Width
    berm_width = 0;
    % Berm Slope
    berm_slope_tana= 1;% Can't set to 0, Will cause 1/0 in Goda Pressure Calcs
end
offshore_slope_tana = 1./structure.offshore_slope;
% Rubblemound Fields
switch struc_type
    case 4
        % Delta
        delta = structure.armor_delta;
        P=0;
    case 3
        % Delta
        delta = structure.armor_delta;
        % Seaside Limit State
        S = structure.seaside_design_S;
        S_ls = structure.leeside_design_S;
        % CEM P
        P = structure.cem_P;
    case  2
        wall_bottom_elev = abs(structure.wall_bottom_elevation);
        hw = crest_elev - wall_bottom_elev;
        toe_elev = wall_bottom_elev;
        P=0;
end
% Water Density kg/m^3
rho_w = config.water_density;
% GET BW SPECIFIC FIELDS
if ismember(struc_type, [3, 4])
    SG = 1 + structure.armor_delta;% Armor Stone Specific Gravity
    dr = SG*rho_w;% Armor Stone Density [kg/m^3]
    V_ss = structure.seaside_mass/dr; % Seaside Median Volume of Armor Stone
    SDn = V_ss^(1/3);% (LCBW) Seaside Nominal Stone Diameter (m)
end
% Get Slopes
if ismember(struc_type, [1, 3, 4])
    % Seaside Slope (cot(alpha))
    mound_seaside_slope_cota = structure.seaside_slope;
    % Leeside Slope
    mound_leeside_slope_cota = structure.leeside_slope;
end

%% GET FORCING FIELDS
% Grab Workflow Specific Fields
switch workflow
    case {1,4} % RB
        % Create Forcing Variables For Simplicity
        SWL = project_forcing.SWL; % SWL
        Hm0 = project_forcing.Hm0; % Hm0
        Tp = project_forcing.Tp; % Tp
        h = cellfun(@(x) x - toe_elev, SWL, 'un', false);
        Rc = cellfun(@(x) crest_elev - x, SWL, 'un', false);
        dt = cellfun(@(x) x*24*3600, project_forcing.dt, 'un', false); % Convert from days to seconds
    case 3 % LCS
        SWL = cellfun(@(x) x(:,5),project_forcing,'un',false); % SWL
        Hm0 = cellfun(@(x) x(:,6),project_forcing,'un',false); % Hm0
        Tp = cellfun(@(x) x(:,7),project_forcing,'un',false); % Tp
        h = cellfun(@(x) x - toe_elev, SWL, 'un', false);
        Rc = cellfun(@(x) crest_elev - x, SWL, 'un', false);
        dt = cellfun(@(x) x(:, 9)*24*3600,project_forcing,'un',false); % dt
end
% Compute Water Depth @ Berm
hb = cellfun(@(x) x - berm_elev, SWL,'un',false);
% Compute Mean Period
Tm = cellfun(@(x) x./1.2,Tp,'un',false); % 
% Compute Zeroth Moment Spectral Wave Period
Tm10 = cellfun(@(x) x./1.1,Tp,'un',false); % 
% Compute Ts
Ts = Tp; % Assuming narrow spectrat Ts~Tp

%% COMPUTE STRUCTURE RESPONSE
% Intialize LCBW Flag
calc_FS_lcbw = 0;
%
if no_resp~=0
    % Call Eurotop Influence Factors
    gammas = cellfun(@(x,y) call_eurotop_ifactors(config, structure, x, y),SWL,Hm0,'un',false);
    % Compute Structure Type Dependant Responses
    switch struc_type
        case 2 % Floodwall
            % Reformat Slope If Needed
            slope_aux = cellfun(@(y) zeros(size(y)), SWL, 'un', false);
            % Compute runup & Overtopping
            if calc_q == 1 || calc_nappe == 1
                [~,~, Resp.q, q_overflow, Resp.q_wave_ot]=cellfun(@(a, b, c, d, e, f) Eurotop_r2p_q_Final(a, b, c, d,...
                    f, e.gamma_f, e.gamma_beta_r2p, e.gamma_beta_q, e.gamma_star, e.gamma_v, e.gamma_b,...
                    wall_bottom_elev, P, g, struc_type),...
                    Hm0, Tm10, SWL, Rc, gammas, slope_aux,'un',false);
            end
            % Compute Wall Pressures
            if calc_p1 == 1 || calc_p2_p3 == 1
                % P1
                Resp.p1 = cellfun(@(a, b, c, d) goda_forces_on_vertical_p1(a, b, 1.8,...
                    0, c, d, berm_width, rho_w, g, offshore_slope_tana, berm_slope_tana), Hm0, Ts, h, hb, 'un', false);
            end
            %
            if calc_p2_p3 == 1
                % Compute P2 & P3 Wall Pressures (Plots)
                [Resp.p2dyn, Resp.p2sta, Resp.p2total,...
                    Resp.p3dyn, Resp.p3sta, Resp.p3total, Resp.pu] = cellfun(@(a, b, c, d, e, f) goda_forces_on_vertical_p2p3(a, b, 1.8,...
                    0, c, d, e, hw, f, rho_w, g), Hm0, Ts, h, hb, Rc, Resp.p1, 'un', false);
            end
            %
            if calc_nappe == 1
                [Resp.X_low, Resp.theta_low, Resp.X_up,...
                    Resp.theta_up, Resp.Bx, Resp.X_c_surge,...
                    Resp.theta_center, Resp.Bjet, Resp.Vjet,...
                    Resp.Fjet] = cellfun(@(a, b, c) floodwall_nappe_response(a, b,...
                    c, hw, rho_w), SWL, Hm0, Resp.q, 'un', false);
            end
        case {1,3,4} % Levees & Rubblemound & LCBW
            % Reformat Slope If Needed
            slope_aux = cellfun(@(y) repmat(mound_seaside_slope_cota, size(y)), SWL, 'un', false);
            % Compute runup & Overtopping
            if calc_r2p == 1 || calc_q == 1 || calc_q_vol == 1
                [Resp.R2p, Resp.R2p_SWL, Resp.q, ~, Resp.q_wave_ot]=cellfun(@(a, b, c, d, e,f) Eurotop_r2p_q_Final(a, b, c, d,...
                    f, e.gamma_f, e.gamma_beta_r2p, e.gamma_beta_q, e.gamma_star, e.gamma_v, e.gamma_b,...
                    toe_elev, P, g, struc_type),...
                    Hm0, Tm10, SWL, Rc, gammas, slope_aux,'un',false);
            end
            % Compute Stone Size Using S Limit State
            if struc_type == 3 || struc_type == 4
                % Dn50 Seaside (Melby - Momentum Flux)
                if calc_dn50_ss == 1
                    [Resp.Dn50] = cellfun(@(a, b, c, d) melby_Dn50_seaside_stability(a, b, c,...
                        duration, mound_seaside_slope_cota, delta, P, S, g, emp_coeff.km1, emp_coeff.km2, d),...
                        Hm0, Tm, h, Rc,'un',false);
                    % Compute Damage When Structure Is Submerged
                   if calc_dn50_submerged == 1
                       % Call Submerged Equation Here
                       [Resp.Dn50, ~] = cellfun(@(a,b,c,d,e) submerged_stone_armor_stability(a, b, c, d, e,crest_elev,S,delta,g),...
                           Hm0, Tp, h, Rc, Resp.Dn50, 'un', false);
                   end
                end
                % Leeside
                if calc_dn50_ls == 1
                    %
                    [Resp.Dn50_Lee] = cellfun(@(a,b,c,d,e) ...
                        van_gent_Dn50_leeside_stability(S_ls, a, b, c, d,...
                        crest_width,mound_seaside_slope_cota, mound_leeside_slope_cota, duration, delta, g,...
                        emp_coeff.k_ls1, emp_coeff.k_ls2, e.gamma_f),...
                        Hm0, Tm10, Tm, Rc, gammas,'un',false);
                    % Compute Damage When Structure Is Submerged
                    if calc_dn50_submerged == 1
                        % Call Submerged Equation Here
                        [Resp.Dn50_Lee, ~] = cellfun(@(a,b,c,d,e) submerged_stone_armor_stability(a, b, c, d, e,crest_elev,S_ls,delta,g),...
                            Hm0, Tp, h, Rc, Resp.Dn50_Lee, 'un', false);
                    end
                end
            end
            % Dn50 Seaside Low Crested Breakwater
            if calc_dn50_lcbw == 1
                %{
                    Melby addition for LCBW. This is a temporary fix for Midbay. Ultimately we will have a branch whether  
                    breakwater is normal or low-crested.  In that case, there will not be a separate crest elevation for low-crested structure.  
                    However, for Midbay, we have both normal structure and low crested because toe berm is at MLLW. 
                    So we have both normal and LC (toe berm) stability computed in same sim.
                %}
                if workflow == 3 % Compute Stability Number (Ns)
                    calc_dn50_lcbw = 0; % Turn Of To Pull Correct Label
                    calc_FS_lcbw = 1; % Turn On To Pull Correct Label
                    % Compute LCBW FS
                    [Resp.FS_LCBW] = cellfun(@(a,b) melby_low_crested_stability(a, b, delta, SDn), Hm0, Rc,'un', false);
                else % Compute Dn50 (PROS)
                    [Resp.Dn50_LCBW] = cellfun(@(a,b) melby_low_crested_stability(a, b, delta, []), Hm0, Rc, 'un', false);
                end
            end
    end
    if calc_wave_transmission == 1
        if exist('mound_seaside_slope_cota', 'var')
            seward_slope_tana=1/mound_seaside_slope_cota;
        elseif exist('berm_slope_tana', 'var')
            seward_slope_tana=berm_slope_tana;
        else 
            seward_slope_tana = 0;
        end
        [Kt] = cellfun(@(a,b,c) eurotop_wave_transmission(a,b,c,crest_width,seward_slope_tana,g),Hm0,Tp,Rc,'un',false);
        % Compute Transmitted Wave
        switch workflow
            case {1,4} % PROS
                Resp.Hm0t = cellfun(@(x, y) x.*y, project_forcing.('Hm0_no_rep'), Kt, 'un', false); 
            case 3 % LCS
                Resp.Hm0t = cellfun(@(x, y) x.*y, Hm0, Kt, 'un', false); % This is only correct for LCS, Deterministic Calc
        end
    end
    % Damaging Depth Response
    if calc_dd == 1
        [Resp.DamDepthElev, Resp.DamDepth]= cellfun(@(x, y, z) damaging_depth(x, y, z, SPdepth, g, calc_dd_ks, offshore_slope_tana), SWL, Hm0, Tp, 'un', false);
    end
    % Compute Overtopping Volume
    if calc_q_vol == 1 && length(Resp.q{1}(:,1)) > 1
        Resp.Q_vol = cell2mat(cellfun(@(x, y) sum(x.*y,1,"omitnan"),Resp.q, dt, 'un',false));
        Resp.Q_vol_wave_ot = cell2mat(cellfun(@(x, y) sum(x.*y,1,"omitnan"),Resp.q_wave_ot, dt, 'un',false));
    end
else % No Responses Computed
    Resp = [];
end

%% FLATTEN DATA & STORE RESPONSES
if get_max == 1
    % Build Var Inventory Logical Vector
    var_bool = [calc_dn50_ss, calc_dn50_ls, calc_dn50_lcbw, calc_FS_lcbw, calc_r2p, calc_r2p, calc_q, calc_q, calc_p1, calc_dd, calc_dd, calc_wave_transmission];
    var_names = {'Dn50', 'Dn50_Lee', 'Dn50_LCBW', 'FS_LCBW', 'R2p', 'R2p_SWL', 'q', 'q_wave_ot', 'p1', 'DamDepth', 'DamDepthElev', 'Hm0t'};
    % Evaluate According To Workflow
    switch workflow
        case {1, 4} % Find Max Responses For Timeseries (RB3)
            %
            var_names = var_names(var_bool == 1);
            %
            if calc_q_vol == 1
                vars_to_find = [var_names,{'Q_vol_wave_ot', 'Q_vol'}];
            else
                vars_to_find = var_names;
            end
            % Remove Unwanted Fields
            rm_indx = sum(cell2mat(cellfun(@(x) strcmp(fieldnames(Resp), x), vars_to_find, 'un', false)), 2) == 0;
            if any(rm_indx)
                rm_names = fieldnames(Resp);
                Resp = rmfield(Resp, rm_names(rm_indx));
            end
            % Loop Through Each Response
            for vv = 1:length(var_names)
                Resp.(var_names{vv}) = cell2mat(cellfun(@(x) max(x,[],1), Resp.(var_names{vv}), 'un', false));
            end
    end
end
end