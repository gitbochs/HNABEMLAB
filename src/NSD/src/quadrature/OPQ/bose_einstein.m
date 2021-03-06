% BOSE_EINSTEIN Bose-Einstein integral.
%
function [xw,Ncap,kount]=bose_einstein(N,M,eta,theta,k,eps0,Nmax)
global mc mp iq idelta irout AB Z ab0 
%
% Be sure to declare the variable theta global also in the routines
% R_MOD and QUADRAT and make the changes indicated in the routine 
% QUADRAT and FEX32.
%
mc=1; mp=0; iq=1; idelta=2; irout=1; 
AB=[0 Inf];
%
% When theta is "large", increase eps0 to avoid an excessively
% large value of Nmax that would be needed for convergence. Also
% increase Nmax appropriately. For example,
%               eps0=1e6*eps; Nmax=800;
%
ab0=r_laguerre(Nmax,k-1);
if M>2
  for m=1:2:M-2
    Z(m,1)=-1/(eta+(m+1)*pi*i); Z(m,2)=1;
    Z(m+1,1)=-1/(eta-(m+1)*pi*i); Z(m+1,2)=1;
  end
end
if M>0
  Z(M,1)=-1/eta; Z(M,2)=1;
end
[abmod,Ncap,kount]=r_mod(N,ab0);
xw=gauss_rational(N,abmod);
