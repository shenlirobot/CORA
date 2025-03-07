function res = example_nonlinear_reach_12_adaptive()
% example_nonlinear_reach_12_adaptive - example for nonlinear reachability
%    analysis using adaptive parameter tuning
%
% Syntax:  
%    example_nonlinear_reach_12_adaptive
%
% Inputs:
%    no
%
% Outputs:
%    res - boolean
%
% References:
%   -

% Author:        Mark Wetzlinger
% Written:       02-February-2021
% Last update:   ---
% Last revision: ---

%------------- BEGIN CODE --------------

res = false;

% system dimension
dim_x = 2;

% parameters
params.tFinal = 8;
params.R0 = zonotope([[1;1],0.1*diag(ones(dim_x,1))]);
params.U = zonotope(0);

% algorithm parameters
options.alg = 'lin-adaptive';

% init system
sys = nonlinearSys(@jetEngine,dim_x,1);

adapTime = tic;
[R,~,opt] = reach(sys,params,options);
tComp = toc(adapTime);

endset = R.timePoint.set{end};
gamma_o = 2*rad(interval(endset));

% simulation ------------------------------------------------------
simOpt.points = 10;                % number of initial points
simOpt.fracVert = 0.8;             % fraction of vertices initial set
simOpt.fracInpVert = 0.5;          % fraction of vertices input set
simOpt.inpChanges = 1;             % changes of input over time horizon

simRes = simulateRandom(sys,params,simOpt);

% computation of gamma_min
endpoints = zeros(sys.dim,simOpt.points);
for i=1:simOpt.points
    endpoints(:,i) = simRes.x{i}(end,:)';
end
simendset = interval.enclosePoints(endpoints);
gamma_u = 2*rad(interval(simendset));
gamma_min = min(gamma_u ./ gamma_o);


% visualization ---------------------------------------------------

% plotting settings
setedgeblue = [0.00, 0.45, 0.81];
setedgegray = [0.50, 0.50, 0.50];
fontsize = 17;

% 1. reachable sets and simulation (only prodDes)
h_all = plotAllDim(R,'all','Color',setedgeblue);
set(gcf,'Position',[50,50,1400,700]);
h_all = plotAllDim(simRes,'all','r','Handle',h_all);

% 2. time step size
figure;
subplot(2,2,1); hold on; box on;
title('Time Step Size');
tVec = query(R,'tVec');
cumsumtVec = cumsum(tVec);
tVecSteps = [0;repelem(cumsumtVec(1:end-1),2);cumsumtVec(end)];
plot(tVecSteps,repelem(tVec,2),'Color',setedgeblue);
% axes and labels
% axes([0,params.tFinal,0.9*min(tVec),1.1*max(tVec)]);
ax = gca; ax.FontSize = 11;
xlabel('t','FontSize',fontsize,'interpreter','latex');
ylabel('$\Delta t$','FontSize',fontsize,'interpreter','latex');        

% 3. taylor terms (Rlin and Rerr)
subplot(2,2,2);  hold on; box on;
title('Taylor Orders');
plot(tVecSteps,repelem(opt.tt_lin,2),'Color',setedgeblue);
plot(tVecSteps,repelem(opt.tt_err,2),'Color',setedgegray);
axis([0,params.tFinal,0,max([opt.tt_lin;opt.tt_err])+1]);
ax = gca; ax.FontSize = 11;
legend('$\eta_{lin}$','$\eta_{abs}$','Location','southeast',...
    'FontSize',fontsize-2,'interpreter','latex');
legend box off;
xlabel('t','FontSize',fontsize,'interpreter','latex');
ylabel('$\eta$','FontSize',fontsize,'interpreter','latex');

% 4. zonotope order
subplot(2,2,3); hold on; box on;
title('Zonotope Order');
fullzonorderRtp = sum(opt.zonordersRtp,2);
plot(tVecSteps,repelem(fullzonorderRtp,2),'Color',setedgeblue);
% legend('Location','northwest');
% axes and labels
axis([0,params.tFinal,0,ceil(1.1*max(fullzonorderRtp))]);
ax = gca; ax.FontSize = 11;
xlabel('t','FontSize',fontsize,'interpreter','latex');
if strcmp(options.alg,'lin')
    ylabel('$\rho$','FontSize',fontsize,'interpreter','latex');
elseif strcmp(options.alg,'poly')
    ylabel('$\rho$','FontSize',fontsize,'interpreter','latex');
end

% 5. abstraction order
subplot(2,2,4); hold on; box on;
title('Abstraction Order');
ax = gca; ax.FontSize = 11;
xlabel('t','FontSize',fontsize,'interpreter','latex');
ylabel('$\kappa$','FontSize',fontsize,'interpreter','latex');
plot(tVecSteps,repelem(opt.kappa,2),'Color',setedgeblue);
axis([0,params.tFinal,1,4]);


% completion successful
res = true;

end

%------------- END OF CODE --------------

