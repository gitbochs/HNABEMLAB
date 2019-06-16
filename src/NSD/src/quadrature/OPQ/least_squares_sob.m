% LEAST_SQUARES_SOB Polynomial least squares approximation in Sobolev space.
%
%    This routine generates the (n+1)x(Ns) array phat of Sobolev
%    least squares approximants evaluated at the N abscissae
%    t_k of the discrete Sobolev inner product, and the 
%    (n+1)-vector c of Sobolev_Fourier coefficients. Here, s is 
%    the highest-order derivative appearing in the Sobolev inner
%    product and is determined by the routine automatically
%    from the size of the input array xw. The N values of the
%    derivative of order sig of the nth-degree approximant are
%    output in positions (n+1,sig:s+1:N*s) of the array phat.
%    The Nx(s+1) array of the input array f contains the N values
%    of the given function and its first s derivatives at the
%    points t_k. The abscissae t_k and the weights w_k^{(sig)} of
%    the Sobolev inner product are input via the Nx(s+1) array
%    xw containing the abscissae in the first column and the
%    successive weights for the derivatives in the subsequent
%    columns. The user also has to provide the NxN upper
%    triangular array of the recurrence coefficients for the
%    Sobolev orthogonal polynomials, which for s=1 can be
%    generated by the routine chebyshev_sob.m, and for arbitray
%    s by the routine stieltjes_sob.m.
%
function [phat,c]=least_squares_sob(n,f,xw,B)
N=size(xw,1); s=size(xw,2)-2;
Ns=N*(s+1); p=zeros(n+1,Ns); p2=zeros(1,n+1);
%
% Generate the matrix of Sobolev orthogonal polynomials
% and their derivatives, along with the array of their norms
%
sN=1:s+1:Ns; p(1,sN)=1;
p2(1)=sum(xw(:,2));
t=xw(:,1)';
for k=1:n
  for sig=1:s+1
    sigN=sig:s+1:Ns; 
    bsum=zeros(1,N);
    for j=1:k
      bsum=bsum+B(j,k)*p(k-j+1,sigN);
    end
    if sig==1
      p(k+1,sigN)=t.*p(k,sigN)-bsum;
    else
      p(k+1,sigN)=t.*p(k,sigN)+(sig-1).*p(k,sigN-1)-bsum;
    end
    p2(k+1)=p2(k+1)+sum(xw(:,1+sig)'.*(p(k+1,sigN).^2));
  end
end
%
% Compute the matrix of least squares approximants and their
% derivatives, along with the array of Fourier coefficients
%
c=zeros(n+1,1);
phat=zeros(n+1,Ns); e=f;
for k=1:n+1
  for sig=1:s+1
    sigN=sig:s+1:Ns;
    c(k)=c(k)+sum(xw(:,1+sig)'.*e(:,sig)'.*p(k,sigN));
  end
  c(k)=c(k)/p2(k);
  if k==1
    for sig=1:s+1
      sigN=sig:s+1:Ns;
      phat(1,sigN)=c(1)*p(1,sigN);
    end
  else
    for sig=1:s+1
      sigN=sig:s+1:Ns;
      phat(k,sigN)=phat(k-1,sigN)+c(k)*p(k,sigN);
    end
  end
  if k==n+1, return, end
  for sig=1:s+1
    sigN=sig:s+1:Ns;
    e(:,sig)=e(:,sig)-c(k)*p(k,sigN)';
  end
end
