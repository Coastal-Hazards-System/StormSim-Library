function [DamDepthElev,DamDepth]= damaging_depth(SWL,Hm0,Ts,SPdepth,Ks,hs,d,Bm,berm_slope_tana,offshore_slope_tana, g)
%{
LICENSING:
    This code is part of StormSim software suite developed by the U.S. Army
    Engineer Research and Development Center Coastal and Hydraulics
    Laboratory (hereinafter “ERDC-CHL”). This material is distributed in
    accordance with DoD Instruction 5230.24. Recipient agrees to abide by
    all notices, and distribution and license markings. The controlling DOD
    office is the U.S. Army Engineer Research and Development Center
    (hereinafter, "ERDC"). This material shall be handled and maintained in
    accordance with For Official Use Only, Export Control, and AR 380-19
    requirements. ERDC-CHL retains all right, title and interest in
    StormSim and any portion thereof and in all copies, modifications and
    derivative works of StormSim and any portions thereof including,
    without limitation, all rights to patent, copyright, trade secret,
    trademark and other proprietary or intellectual property rights.
    Recipient has no rights, by license or otherwise, to use, disclose or
    disseminate StormSim, in whole or in part.

DISCLAIMER:
    STORMSIM IS PROVIDED “AS IS” BY ERDC-CHL AND THE RESPECTIVE COPYRIGHT
    HOLDERS. ERDC-CHL MAKES NO OTHER WARRANTIES WHATSOEVER EITHER EXPRESS
    OR IMPLIED WITH RESPECT TO STORMSIM OR ANYTHING PROVIDED BY ERDC-CHL,
    AND EXPRESSLY DISCLAIMS ALL WARRANTIES OF ANY KIND, EITHER EXPRESSED OR
    IMPLIED, INCLUDING WITHOUT LIMITATION, WARRANTIES OF MERCHANTABILITY,
    NON-INFRINGEMENT, FITNESS FOR A PARTICULAR PURPOSE, FREEDOM FROM BUGS,
    CORRECTNESS, ACCURACY, RELIABILITY, AND RESULTS, AND REGARDING THE USE
    AND RESULTS OF THE USE, AND THAT THE ASSOCIATED SOFTWARE’S USE WILL BE
    UNINTERRUPTED. ERDC-CHL DISCLAIMS ALL WARRANTIES AND LIABILITIES
    REGARDING THIRD PARTY SOFTWARE, IF PRESENT IN STORMSIM, AND DISTRIBUTES
    IT “AS IS.” RECIPIENT AGREES TO WAIVE ANY AND ALL CLAIMS AGAINST
    ERDC-CHL, THE UNITED STATES GOVERNMENT AND ITS CONTRACTORS AND
    SUBCONTRACTORS, AND SHALL INDEMNIFY AND HOLD HARMLESS ERDC-CHL, THE
    UNITED STATES GOVERNMENT AND ITS CONTRACTORS AND SUBCONTRACTORS FOR ANY
    LIABILITIES, DEMANDS, DAMAGES.

SOFTWARE NAME:
    Damaging_Depth_11_27_24.m

DESCRIPTION:
    Function to compute damaging depth as the total water column height from 
    the topographic surface to the peak of the controlling wave height.
    Damaging depth = SWL+0.7*Hc
    The controlling wave height, Hc, is defined as the average height of the highest 
    1-percent of waves during storm conditions. It is limited to the theoretical 
    breaker limit using Goda's breaker equation. 70 percent of the controlling 
    wave height is assumed to lie above the SWL. This approach assumes that SWL includes 
    all storm water level components including surge, tide, and wave setup. 
    Ks is sheltering coefficient: 1 for 0-1 rows, 0.7 for 2-3 rows, 0.5 for 4-5 rows, 0.3 for≥6 rows

INPUT/OUTPUT ARGUMENTS:
    DamDepthEelev: damaging depth elevation
    DamDepth: damaging depth
    SPdepth: datum depth of save point
    Hm0: zero moment significant wave height
    Tp:  peak wave period
    SWL: total water level
 hs      = seaward depth, ft
    d       = water depth from top of berm, ft
    B       = width of caisson, ft    
    gamma_c = specific weight of caisson, pcf
    Bm      = berm width, ft
    berm_slope_tana       = Seaward slope of toe berm (tana)   
    offshore_slope_tana = Seabed slope (tana)

    Ks: Shielding parameter
        1 for 0 - 1 rows of buildings
        0.7 for 2 - 3 rows of buildings
        0.5 for 5 - 5 rows of buildings
        0.3 for >= 6 rows of buildings

AUTHORS:
    Jeffrey A. Melby (JAM)

HISTORY OF REVISIONS:

***************  ALPHA  VERSION  **  FOR INTERNAL TESTING ONLY ************
%}
var_shape = size(Ts);
Ts = Ts(:); %note that Ts=0.93*Tp for Jonswap with gamma=3.3 but approaches Tp as gamma 
Hm0 = Hm0(:);
SWL = SWL(:);
% increases (spectrum becomes narrower).  So here we assume narrow spectra to be conservative.
[Hb, ~]=goda_Hmax(Hm0,Ts,1.6,hs,d,Bm,berm_slope_tana,offshore_slope_tana, g);

DamDepthElev = SWL + 0.7 * Ks * Hb;
DamDepth = DamDepthElev - abs(SPdepth);
% Resahpe Variables 
DamDepth = reshape(DamDepth, var_shape);
DamDepthElev = reshape(DamDepthElev, var_shape);
end