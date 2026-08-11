function iVar_w_u = pcha_forcing_uncertainty(iVar, u_a, u_r, normU)
%{
Notes on how to check uncertainty:
1. SWL_mean (across cols) -> Original value for SWL (without uncert)
    sum(mean(iVar_w_u,2) == iVar(:,1)) ~ number_of_storms
2. Std ~ SWL_mean * SWL_U_r
3. Hist for each row choose 
%}
a = u_a+iVar; r = u_r.*iVar;
if u_a == 0
    u_iVar = 1./sqrt(1./(r).^2);
elseif u_r == 0
    u_iVar = 1./sqrt(1./(a).^2);
    u_iVar = u_iVar .* (a./abs(a));
else
    u_iVar = 1./sqrt(1./(a).^2 + 1./(r).^2);
    u_iVar = u_iVar .* (a./abs(a));
end
iVar_w_u = iVar + u_iVar.*normU;
end