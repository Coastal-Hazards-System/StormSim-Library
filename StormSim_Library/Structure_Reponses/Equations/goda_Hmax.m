function [Hmax, hb]=goda_Hmax(Hm0,Ts,Rayleigh_H250,hs,d,Bm,berm_slope_tana,offshore_slope_tana,g)
%{ 
Goda book page 105, 2000 edition
Kamphuis irregular wave equation for Hb, Eq 3.34
Confirmed by Li et al.

Determine breaking wave at 5Hm0 from structure
breaking wave can be on berm or on offshore slope
Be consistent with naming slopes so that both user and coder know if
slope is tangent or cotangent

Input Definitions: 
    Hm0     = significant wave height
    Tp      = peak wave period
    hs      = depth at seaward berm toe or wall toe if no berm
    d       = water depth from top of berm
    Bm      = berm crest width
    tanalpha      = tangent of berm slope
    tanbeta       = tangent of offshore slope
    Rayleigh_H250 = 1.8
    hb  = breaker depth
    toe_dist = distance from structure to berm toe
    b_dist = 5Hm0 distance from structure 
%} 
Hm0 = Hm0(:);
Ts = Ts(:);
hs = hs(:);
d = d(:);
Bm=Bm(:);
 
%%  PREPROCESSING
% Initialize hb
hb = zeros(size(hs));
% Compute location of 5Hm0 from wall
b_dist = 5*Hm0;
if Bm>0
    % Compute Berm "toe" Distance From Wall
    toe_dist = 1./berm_slope_tana*(hs-d)+Bm;
    % is 5H location on berm?
    if b_dist < toe_dist
        % Is 5H location on slope of berm
        if b_dist > Bm
            hb = d + berm_slope_tana*(b_dist - Bm);
        else
            % 5H location on top of berm
            hb = d;
        end
       tan_b_slope = berm_slope_tana;  
    else
    % 5H location offshore of berm toe
        hb = hs + offshore_slope_tana * (b_dist - toe_dist);
        tan_b_slope = offshore_slope_tana;
    end
% no berm
else
      hb = hs + offshore_slope_tana * b_dist;
      tan_b_slope = offshore_slope_tana;
end
% Negative Water Col Failsafe
hb(hb<0) = 0;

%% DEPTH LIMITATION 
% Goda says to use Ts = T1/3.  He says use Ts = Tm-1,0.  Ts=0.93*Tp for Jonswap with gamma=3.3 but approaches Tp as gamma 
% increases (spectrum becomes narrower).  
% Deep Water Wave Length 
Lo = g*Ts.^2/2/pi;
% Compute maximum significant wave height in the surf zone (Depth Limitation)
%HbonLo(:, 1) = 0.17*(1-exp(-1.5*pi*SPdepth/Lo*(1+15*tanbeta^(4/3)))); %Goda, 1995
HbonLo(:, 1) = 0.12.*(1-exp(-1.5.*pi.*hb./Lo.*(1+11.*tan_b_slope^(4/3)))); %Goda, 1995
Hb = HbonLo.*Lo;
% Keep Smallest 
Hmax = min(Hb, Hm0.*Rayleigh_H250, "omitnan");
end
