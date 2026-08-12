function [p1dyn]=goda_forces_on_vertical_p1(Hm0,Ts,design_scale,beta,hs,d,Bm, rho_w, g, offshore_slope_tana, berm_slope_tana)
%{
Note - inputs to the function are in metric and are switched at the beginning of the code to imperial. 
Output is also in metric. 

This script computes Goda pressures, forces, and moments on a vertical wall
using methods from Table VI-5-53 and Table VI-5-55 in the CEM. 

Assumptions: Full wall (not partial), irregular non-breaking waves,
includes berm option.

account for depth induced wave breaking. Breaking waves by severe wave conditions solely
(white-capping) is not included in the formula

Input Definitions: 
    Hm0     = significant wave height, ft
    Ts      = peak wave period, s
    beta    = wave obliquity, degrees
    hs      = seaward depth, ft
    d       = water depth from top of berm, ft
    B       = width of caisson, ft    
    gamma_c = specific weight of caisson, pcf
    Bm      = berm width, ft
    berm_slope_tana       = Seaward slope of toe berm (tana)   
    offshore_slope_tana = Seabed slope (tana)

Output Definitions:
    p1dyn = total pressure at still water level
    

Written by Abigail L. Stehno (abigail.l.stehno@erdc.dren.mil) 11./17./21

Validation test: 
Validation test: (inputs are metric)
p1dyn = goda_forces_on_vertical_p1(1.9507, 7.7, 1.8, 2, 5.7607, 5.1511, 0.3048, 10, 1025.502, 9.81,18.9/3.2808,10);

p1: 187.7356 lbf/ft^2 =  8.9922e03 Pa

Comments from Jeff
- Include a code that calls this function set up with one of the examples. 
- Looks like this is for a wall with no water on back side because it has 
  hydro static.  That needs a clear comment up front.  Ideally it is not 
  assumed but there should be a user-defined logical for hydrostatic./no hydrostatic.
- Breaker index (0.6) should be a user input
- The period in Goda equation is not Tp, it is "significant wave period" or 
  Tm-1,0 or 1.1Tm or Tp./1.1 
- Uplift force assumes caisson is sitting on a gravel base.  What if structure 
  is not on a gravel base?  What if it is a pile-founded I-wall or T-wall?  
  This could be a logical (uplift pressures are possible or not). 
- For moments, add to comments that they are computed about heel of caisson. 
  The actual rotation point is fairly complex and there is a method to compute
  it for caissons.  But if it is a floodwall, it is very different and depends
  on the geometry and the geotechnical failure location.   
%}

%% VECTORIZE INPUTS 
data_dims = size(Hm0);
Hm0 = Hm0(:)*3.2808; % ALS changed to imperial 7/28
Ts = Ts(:);
beta = beta(:);
hs = hs(:)*3.2808; % ALS changed to imperial 7/28
d = d(:)*3.2808; % ALS changed to imperial 7/28
 Bm=Bm(:)*3.2808;
rho_w = rho_w*0.062428;
g=g(:)*3.28084; 
 
%%  PREPROCESSING
% Height between SWL and top of caisson (hc)
% hc = hw-hs;
% Negative Water Col Failsafe
hs(hs<0) = 0; d(d<0)=0; 
% lambda coefficients - Vertical Wall
lambda1 = 1; % More Cases Will Be Added In The Future
lambda2 = 1;
% Define Constants
gamma_w = rho_w.*g/32.17405; % Specific weight of water, pcf % ALS changed to imperial 7/28

%% DEPTH LIMITATION 
%note that Ts=0.93*Tp for Jonswap with gamma=3.3 but approaches Tp as gamma 
% increases (spectrum becomes narrower).  So here we assume narrow spectra to be conservative.
[H_design, hb]=goda_Hmax(Hm0,Ts,design_scale,hs,d,Bm,berm_slope_tana,offshore_slope_tana, g);

%% COMPUTE WAVE NUMBER
% Wave length
[kp,~,~]=wavnum1_VG(Ts,d,g); % 1./ft
kp_hs = kp.*hs; % k_p .* h_s, unitless

%% COMPUTE ALPHA'S
% Alpha coefficients
alpha1 = 0.6+0.5.*(2.*kp_hs./sinh(2.*kp_hs)).^2;
alpha2 = min([(hb-d)./3./hb.*(H_design./d).^2, 2.*d./H_design],[],2,"omitnan");
alphaStar = alpha2;

%% COMPUTE P1 (Table VI-5-53 in CEM)
p1dyn=0.5.*(1+cos(beta)).*(lambda1.*alpha1+lambda2.*alphaStar.*...
    (cos(beta).^2)).*gamma_w.*H_design; % hydrodynamic p1 at SWL
% Reshape 
p1dyn = reshape(p1dyn,data_dims)*47.8803;
end


