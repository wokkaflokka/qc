function [fs xs a] = rpw2dsample_multi(n0, ppws, e, opts)
% RPW2DSAMPLE - gridded sample from distribution of 2D random plane waves
%
% [f x] = rpw2dsample(n, ppw) generates n-by-n array of function values f
%   whose coordinates are given by the list x in each dimension, ie f(i,j)
%   is the value of the function at location (x(i),x(j)) in the plane. The
%   function is a sample from the distribution of random real-valued plane
%   waves. ppw is the number of x-points per wavelength of the waves (>2).
%   The normalization is that f has root-mean square value of 1.
%
% [f x] = rpw2dsample(n, ppw, e) uses Gaussian tail convergence parameter e.
%   Increasing e from 5 to say 7 improves accuracy but slows it down.
%
% [f x] = rpw2dsample(n, ppw, [], opts) or [f x] = rpw2dsample(n, ppw, e, opts)
%   allows certain options to be controlled, namely:
% opts.real : if true (default), make real-valued, otherwise complex
% opts.expt : if 'c', calibrate errors by using a single delta function, makes
%                     plot outputs
%             if 'b', calibrate via a J0-Bessel function, makes plots
%             if 'r' (default), output random plane wave, no plots
%             if 'p' output random plane wave, make plots
%
% The algorithm is pretty-much optimal, using nonuniform FFT: computation
% time O(n^2 ln n), memory O(n^2), and giving spectral (in fact quadratic)
% convergence in the parameter e. Arrays of size 4n*4n are used, so the largest
% practical n depends on your RAM. Typically 1024 is the largest to avoid
% disk swapping with 2GB RAM.
%
% Examples:
%
%   % computes and plots a sample function from the RPW distribution
%   rpw2dsample(1024, 7, [], struct('expt', 'p'));  shows a plot of an RPW
%
%   % extracts data and plots by hand
%   [f x] = rpw2dsample(1024, 7);
%   imagesc(x, x, f'); set(gca, 'ydir', 'normal'); axis equal;
%
%   % shows pointwise errors in the method
%   rpw2dsample(1024, 7, [], struct('expt', 'c'));
%
% (C) 2006, 2009. Alex Barnett. Date 8/4/09
% 
% Adapted to sample on grids of various dx
% Kyle Konrad 4/9/2012

  if nargin<3 || isempty(e), e = 5; end   % default Gaussian tail conv param
  if nargin<4, opts = []; end
  real = 1; if isfield(opts, 'real'), real = opts.real; end; opts.real = real;
  expt = 'r'; if isfield(opts, 'expt'), expt = opts.expt; end
  
  fs = cell(1,numel(ppws));
  xs = cell(1,numel(ppws));
  i = 1;

  N = 2*ceil(4*n0*pi/ppws(1));
  if opts.real
      a = randn(1,N/2); a = [a a];  % inv symm Re part
      b = randn(1,N/2); b = [b -b]; % flip Im part for herm symm
  else
      a = randn(1,N); % complex case
      b = randn(1,N); % complex case
  end
  
  for ppw=ppws
  n = n0*(ppw / ppws(1)); % scale number of points with ppw
  n = round(4*n);              % make computational grid 4 times in each direction
  ns = ((1:n)-n/2-1);   % offset integer lattice
  dx = 2*pi/ppw; x = dx*ns;            % 1d position grid (same for both coords)
  dk = ppw/n;    k = dk*ns;           % 1d wavenumber grid
  N = 2*ceil(pi/dk); dt = 2*pi/N; t = ((1:N)-1/2)*dt;  % # samples around S^1
  
  s = e*dk;   % gaussian width in wavenumber
  if (1+s)>ppw/2
    warning('gaussian tails overspill k domain! s=%g',s); end

  if expt=='c'
    F = circle_blobs(0, 1, 0, ppw, n, dk, e);   % F(k) = unit-strength delta
    fprintf('frac err in sum of F(k) = %g', sum(F(:))-1);
  else
    if expt=='b'        % usual (1/2pi) amplitude on S^1 for J_0 bessel
      F = circle_blobs(t, dt*ones(1,N) / (2*pi), 1, ppw, n, dk, e);
    else           % 'r': random plane waves: real-valued case
      R = 1;
      F = circle_blobs(t, dt*a, R, ppw, n, dk, e);

      G = circle_blobs(t, dt*b, R, ppw, n, dk, e);
      F = sqrt(N/2)/(2*pi) * (F + 1i*G); clear G; % cmplx F(k), for RMS f = 1
      a = a + 1i*b;
    end
  end
  % Compute by inv FFT spatial function, f(x) := int F(k) e^{-ikx} dk
  if opts.real, tic;
    f = n*n*circshift(ifft2(circshift(F,[n/2 n/2]), 'symmetric'),[n/2 n/2]);
    fprintf('%dx%d 2D fft done in %g sec', n,n,toc);
  else tic; f = n*n*circshift(ifft2(circshift(F,[n/2 n/2])),[n/2 n/2]);
    fprintf('%dx%d 2D fft done in %g sec', n,n,toc);
  end

  % truncate to useful region... central 1/4 is good (err<3e-4 for e=5)
  j = 1+3*n/8:5*n/8; tn = numel(j); tf = f(j,j); x = x(j); % x overwritten
  % undo k-space convolution by x-space division by gaussian...
  xx = repmat(x, [tn 1]); xx2 = xx.^2; f = tf .* exp(s*s*(xx2+xx2')/2);
  fs{i} = f;
  xs{i} = x;
  % Calc is done; now do various calibration outputs...
  if expt=='c'   % show spatial plot of errors... will show error size in RPWs
    figure; imagesc(x,x,log10(abs(1-f))');set(gca, 'ydir', 'normal');
    axis equal; caxis([-10 0]); colorbar; xlabel('x_1'); ylabel('x_2');
    title(sprintf('expt=c: log10(f(x)-1), n=%d ppw=%g e=%g',n,ppw,e));
    fprintf('error in f val in middle = %g', f(1+tn/2,1+tn/2)-1);
  
  elseif expt=='b'  % remember J0 dies like |x|^{-1/2} so are smaller at edge
    figure; imagesc(x,x,log10(abs(besselj(0,sqrt(xx2+xx2')) - f))');
    set(gca, 'ydir', 'normal'); axis equal; caxis([-10 0]); colorbar;
    xlabel('x_1'); ylabel('x_2'); axis tight;
    title(sprintf('expt=b: log10(f(x)-J_0(|x|)), n=%d ppw=%g e=%g',n,ppw,e));
  
  elseif expt=='p'              % show the RPWs themselves...
    figure; imagesc(x,x,f'); axis equal; caxis([-3 3]); colorbar;
    set(gca, 'ydir', 'normal'); xlabel('x_1'); ylabel('x_2'); axis tight;
    title(sprintf('expt=p: f(x), n=%d ppw=%g e=%g',n,ppw,e));
    fprintf('RMS of sample = %g', norm(f(:))/tn);
  end
  i = i+1;
  end