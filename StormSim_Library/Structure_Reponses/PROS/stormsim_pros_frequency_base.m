function data_out = stormsim_pros_frequency_base(config, structure, data_in, outPath, workflow)
    % ==========================================
    % 1. INITIALIZE CONFIG & STRUCTURE DETAILS
    % ==========================================
    proj_name = config.project_name;
    struc_id  = strrep(config.struc_id, '_', ' ');
    case_name = strrep(config.case_name, '_', ' ');
    save_name = fullfile(outPath, [proj_name, '_', struc_id]);
    workflow = config.workflow;
    g = config.gravity_constant;
    rho_w = config.water_density;
    config.compute_q_vol = 0; % Force Q vol to 0
    
    crest_elev = structure.crest_elevation;
    toe_elev   = abs(structure.toe_elevation);
    
    % Berm Logic
    if config.add_berm
        berm_elev  = abs(structure.berm_elevation);
        berm_width = structure.berm_width;
        berm_slope = structure.berm_slope;
    else
        berm_elev  = abs(structure.toe_elevation);
        berm_width = 0;
        berm_slope = 1; 
    end
    
    % Rubblemound / Wall Logic
    if config.struc_type == 2
        hw = structure.wall_bottom_elevation + crest_elev;
    else
        hw = NaN; % Failsafe if accessed outside struc_type 2
    end
    
    emp_coeff = load_empirical_coefficients();
    storm_types = fieldnames(data_in);
    data_out = struct();

    % ==========================================
    % 2. PROCESS EACH STORM TYPE
    % ==========================================
    for st = 1:length(storm_types)
        storm_name = storm_types{st};
        hc_data = data_in.(storm_name);
        
        % Pre-allocate/Clear loop variables to prevent cross-contamination
        Output = [];
        Resp = []; 
        
        x_plt = hc_data(1).x_plot;
        x_tbl = hc_data(1).x_table;
        cl    = hc_data(1).CL;
        
        % Clarified Logic: Can we compute secondary responses directly?
        req_p2_p3 = config.compute_p2_p3 == 1;
        req_nappe = config.compute_nappe == 1;
        has_p1    = any(strcmp({hc_data.var}, 'p1'));
        has_q     = any(strcmp({hc_data.var}, 'q'));
        
        
        % Process both 'y_table' and 'y_plot' seamlessly
        for field_str = ["y_table", "y_plot"]
            field = char(field_str);

            [SWL, pass_swl] = get_hc_data(hc_data, 'SWL', field);
            if ~pass_swl
                [SWL, pass_swl] = get_hc_data(hc_data, 'SSL', field);
            end
            [Hm0, pass_hm0] = get_hc_data(hc_data, 'Hm0', field);
            [Tp,  pass_tp]  = get_hc_data(hc_data, 'Tp', field);
            
            % Abort if minimum hazard curves do not exist
            if ~(pass_swl && pass_hm0 && pass_tp)
                Resp = [];
                continue; 
            end
            
            % Compute Intermediate Variables
            Tm10 = cellfun(@(x) x ./ 1.1, Tp, 'UniformOutput', false);
            h    = cellfun(@(x) x - toe_elev, SWL, 'UniformOutput', false);
            Rc   = cellfun(@(x) crest_elev - x, SWL, 'UniformOutput', false);
            hb   = cellfun(@(x) x - berm_elev, SWL, 'UniformOutput', false);
            
            % Compute Responses
           switch workflow
               case 1 % PROS-RB (Only Compute Secondary Responses As EB1 
                   % Check For Compute Specs
                   can_do_secondary = (~req_p2_p3 || has_p1) && (~req_nappe || has_q);
                   if can_do_secondary
                       if req_p2_p3
                           p1 = get_hc_data(hc_data, 'p1', field);
                           [Resp.(field).p2dyn, Resp.(field).p2sta, Resp.(field).p2total,...
                               Resp.(field).p3dyn, Resp.(field).p3sta, Resp.(field).p3total, Resp.(field).pu] = ...
                               cellfun(@(a, b, c, d, e, f) goda_forces_on_vertical_p2p3(a, b, 1.8, 0, c, d, e, hw, f, rho_w, g), ...
                               Hm0, Tm10, h, hb, Rc, p1, 'UniformOutput', false);
                       end

                       if req_nappe
                           q = get_hc_data(hc_data, 'q', field);
                           [Resp.(field).X_low, Resp.(field).theta_low, Resp.(field).X_up,...
                               Resp.(field).theta_up, Resp.(field).Bx, Resp.(field).X_c_surge,...
                               Resp.(field).theta_center, Resp.(field).Bjet, Resp.(field).Vjet, Resp.(field).Fjet] = ...
                               cellfun(@(a, b, c) floodwall_nappe_response(a, b, c, hw, rho_w), ...
                               SWL, Hm0, q, 'UniformOutput', false);
                       end
                        eb1_fields = fieldnames(Resp.(field));
                        for gg = 1:length(eb1_fields)
                            Resp.(field).(eb1_fields{gg}) = cell2mat(Resp.(field).(eb1_fields{gg})); 
                        end
                   end
               case 4 % PROS-EB2 (Compute All PSE Responses As EB2)
                   % Grab Uncertainty                    
                   tp_u = sqrt(1+config.chs_hm0_u_r)-1; %0.0724
                   swl_u = [config.chs_swl_u_a, config.chs_swl_u_r];
                   hm0_u = [config.chs_hm0_u_a, config.chs_hm0_u_r];
                   % Define MC Samples
                   MCsim = 10000; % For EB2
                   % Sample
                   normU_swl = randn(length(SWL{1}),MCsim);
                   normU_hm0 = randn(length(SWL{1}),MCsim);
                   normU_tp = (1+tp_u.*normU_hm0);
                   % SWL
                   project_forcing.SWL = {pcha_forcing_uncertainty_EB2(SWL{1},...
                       swl_u(1), swl_u(2),...
                       normU_swl, storm_name)};
                   % Hm0
                   project_forcing.Hm0 = {pcha_forcing_uncertainty_EB2(Hm0{1},...
                       hm0_u(1), hm0_u(2),...
                       normU_hm0, storm_name)};
                   % Tp
                   project_forcing.Tp = {Tp{1}.*normU_tp};
                   % Storm Duration
                   project_forcing.dt  = {repmat(datenum(0,0,0,config.storm_duration,0,0), size(SWL{1}))};
                   %
                   Resp.(field) = compute_structure_response(config, structure, project_forcing, emp_coeff, 0);
                   %
                   if ~isempty(Resp.(field))
                       fnames = fieldnames(Resp.(field));
                       for ii = 1:length(fnames)
                           % Sort AEF Vector Across All MC Sims
                           resp_sort = sort(Resp.(field).(fnames{ii}){:}, 2);
                           % Pick Out CL Of Interest
                           Resp.(field).(fnames{ii}) = resp_sort(:, ceil(MCsim.*hc_data(1).CL./100));
                       end
                       % Make Sure To Overwrite R2p+SWL
                       if any(contains(fnames, {'R2p_SWL'}))
                           Resp.(field).('R2p_SWL') = cell2mat(SWL) + Resp.(field).('R2p');
                       end
                   end
           end
        end
        
        % ==========================================
        % 3. APPEND RESULTS TO HAZARD TABLE
        % ==========================================
        if ~isempty(Resp)
            resp_vars = fieldnames(Resp.y_table);
            
            for vv = 1:length(resp_vars)
                v_name = resp_vars{vv};
                [~, ~, ~, unit_label, lbl_name, y_label, y_scale_log] = response_library_headers(config, v_name);
                
                % Formatted Strings
                title_str = {sprintf('StormSim: PROS-FB | %s | %s', case_name, struc_id), ...
                             sprintf('%s | %s [%s]', storm_name, lbl_name, unit_label)};
                out_name  = sprintf('%s_%s_%s_Hazard_Curve.png', save_name, v_name, storm_name);
                
                % Append
                Output = response_appender(Output, vv, v_name, y_label, title_str, ...
                    x_plt, [Resp.y_plot.(v_name)], x_tbl, [Resp.y_table.(v_name)], ...
                    {'Computed using frequency base approach.'}, y_scale_log, cl, out_name);
            end
            
            % Clean up inputs and merge
            if isfield(hc_data, 'tbl_rsp_x')
                hc_data = rmfield(hc_data, {'tbl_rsp_x', 'tbl_rsp_y'});
            end
            
            % Prioritize existing RB calculations using exact matching
            rm_indx = ismember({Output.var}, {hc_data.var});
            data_out.(storm_name) = [hc_data, Output(~rm_indx)];
        else 
            data_out.(storm_name) = hc_data;
        end
    end

    % ==========================================
    % HELPER FUNCTIONS
    % ==========================================
    function Output = response_appender(Output, rIndx, sVar, y_label, title_str, x_plt, y_plt, x_tbl, y_tbl, POT, y_log_scale, CL, outName)
        % Create boolean masks once to avoid evaluating logic 4 separate times
        idx_tbl = x_tbl >= 0.001;
        idx_plt = x_plt >= 0.001 & x_plt <= max(x_tbl);
        
        Output(rIndx).var         = sVar;
        Output(rIndx).CL          = CL; 
        Output(rIndx).x_plot      = x_plt(idx_plt, :);
        Output(rIndx).y_plot      = y_plt(idx_plt, :);
        Output(rIndx).x_table     = x_tbl(idx_tbl, :);
        Output(rIndx).y_table     = y_tbl(idx_tbl, :);
        Output(rIndx).x_table_ARI = x_tbl;
        Output(rIndx).POT         = POT;
        Output(rIndx).y_label     = y_label;
        Output(rIndx).title       = title_str;
        Output(rIndx).y_log_scale = y_log_scale; 
        Output(rIndx).save_name   = outName;
    end

    function [var_out, pass_indx] = get_hc_data(data, varname, field_get)
        var_indx = strcmp(varname, {data.var});
        if any(var_indx)
            pass_indx = true;
            var_out = num2cell(data(var_indx).(field_get), 1);
        else
            pass_indx = false;
            var_out = {NaN};
        end
    end

    function iVar_w_u = pcha_forcing_uncertainty_EB2(iVar, u_a, u_r, normU, stm_type)
        % Need To Adjust Ua, Ur If TC Data (10% -> Partioning Inside JPM)
        switch stm_type
            case {'TC', 'CC'}
                % Partition Uncertainty
                p1_a = 0.1; %same units as response array
                if u_a^2 >= p1_a^2
                    u_a = sqrt(u_a^2-p1_a^2);
                end
                %partition of the relative unc
                p1_r = .1; %dimensionless fraction
                if u_r^2 >= p1_r^2
                    u_r = sqrt(u_r^2-p1_r^2);
                end
        end
        %
        a = u_a+iVar; r = u_r.*iVar;
        u_iVar = 1./sqrt(1./(a).^2 + 1./(r).^2);
        u_iVar = u_iVar .* (a./abs(a));
        iVar_w_u = iVar + u_iVar.*normU;
    end
end