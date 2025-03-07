function R = guardIntersect_pancake(obj,R0,guard,guardID,options)
% guardIntersect_pancake - implementation of the time scaling approach
%                          described in [1]
%
% Syntax:  
%    R = guardIntersect_pancake(obj,R0,guard,options)
%
% Inputs:
%    obj - object of class location
%    R - list of intersections between the reachable set and the guard
%    guard - guard set (class: constrained hyperplane)
%    guardID - ID of the guard set
%    options - struct containing the algorithm settings
%
% Outputs:
%    R - set enclosing the guard intersection
%
% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
%
% See also: none
%
% References: 
%   [1] S. Bak et al. "Time-Triggered Conversion of Guards for Reachability
%       Analysis of Hybrid Automata"

% Author:       Niklas Kochdumper
% Written:      05-November-2018             
% Last update:  20-November-2019
% Last revision:---

%------------- BEGIN CODE --------------

    % initialization
    sys = obj.contDynamics;
    [params,options_] = adaptOptions(obj,options);

    % check if guard set is a constrained hyperplane
    if ~isa(guard,'conHyperplane')
       error('The method ''pancake'' only supports guards given as conHyperplane objects!'); 
    end
    
    % convert hyperplane to a halfspace that represents the outside of the
    % invariant set
    c = center(R0);
    hs = halfspace(guard.h.c,guard.h.d);

    if in(hs,c)
        hs = halfspace(-guard.h.c,-guard.h.d);
    end

    % set default options for nonlinear system reachability analysis
    optionsScal = options_;
    
    if ~isa(sys,'nonlinearSys')
       optionsScal = defaultOptions(options_); 
    end
    
    % create system for the time-scaled system dynamics
    [sys_,params] = scaledSystem(sys,hs,R0,guardID,params);

    % compute the reachable set for the time scaled system 
    R = reachTimeScaled(sys_,hs,R0,params,optionsScal);
    
    % jump accross the guard set in only one time ste
    R = jump(sys,hs,R,options_);

    % project the reachable set onto the hyperplane
    R = projectOnHyperplane(guard,R);

end


% Auxiliary Functions -----------------------------------------------------

function [sys,params] = scaledSystem(sys,hs,R0,guardID,params)
% Scale the system dynamics using the distance to the hyperplane as a 
% scaling factor 

    % get maximum distance of initial set ot hyperplane
    maxDist = supremum(interval(hs.c' * R0 + (-hs.d)));
    params.paramInt = maxDist;

    % define scaling function
    g = @(x,p) (hs.c' * x - hs.d)./p;

    % get system dynamics
    n = sys.dim;
    m = sys.nrOfInputs;
    
    if isa(sys,'linearSys')
       f = @(x,u) dynamicsLinSys(x,u,sys); 
    else
       f = sys.mFile; 
    end

    % time scaled system dynamics
    F = @(x,u,p) g(x,p) * f(x,u);

    % create symbolic variables
    xSym = sym('x',[n,1]);
    uSym = sym('u',[m,1]);
    pSym = sym('p',1);

    % create file path
    name = ['generated_',sys.name,'_',num2str(guardID),'_timeScaled'];
    path = [coraroot filesep 'models' filesep 'auxiliary' filesep name];

    % create file for time scaled dynamics
    func = F(xSym,uSym,pSym);
    matlabFunction(func,'File',path,'Vars',{xSym,uSym,pSym});

    % create time scaled system
    str = ['sys = nonlinParamSys([@' name '],n,m,1);'];
    eval(str);
end

function Rfin = reachTimeScaled(sys,hs,R0,params,options)
% Compute the reachable set of the scaled system such that the final
% reachable set until the scaled reachable set is very close to the
% hyperplane

    % adapt options
    spec = specification(hs,'unsafeSet');
    params.R0 = R0;
    if isfield(options,'maxError')
       options = rmfield(options,'maxError'); 
    end
    
    % compute reachable set until 
    R = reach(sys,params,options,spec);
    
    % get final reachable set
    Rfin = R.timePoint.set{end};
end

function Rcont = jump(sys,hs,R0,options)
% compute the reachable set in such a way that the reachable set jumps in 
% only one time step accross the hyperplane    

    params.R0 = R0;
    timeStep = options.timeStep;
    timeStep_ = timeStep;
    
    % compute reachable set
    options.timeStep = timeStep;
    params.tFinal = timeStep;

    R = reach(sys,params,options);

    % check if located inside the invariant
    dist_ = supportFunc(R.timePoint.set{end},hs.c,'upper') - hs.d;
    
    if dist_ < 0 
    % guard set crossed -> reduce time step size to get smaller set
        
        Rcont = R.timeInterval.set{end};
        distMin = supportFunc(R0,hs.c,'lower') - hs.d;
        lb = 0; ub = timeStep;
        
        for i = 1:10
           
            % update time step
            timeStep = (ub-lb)/2;
            options.timeStep = timeStep;
            params.tFinal = timeStep;
            
            % compute reachable set
            R = reach(sys,params,options);

            % check if located inside the invariant
            dist = supportFunc(R.timePoint.set{end},hs.c,'upper') - hs.d;
            
            if dist < 0
                Rcont = R.timeInterval.set{end};
                ub = timeStep;
                if abs(dist) <= distMin
                    break;
                end
            else
                lb = timeStep;
            end
        end
        
    else
    % guard set not crossed -> increase time interval    
        
         while true
       
            % update time step
            timeStep = timeStep + timeStep_;
            options.timeStep = timeStep;
            params.tFinal = timeStep;
            
            % compute reachable set
            R = reach(sys,params,options);

            % check if located inside the invariant
            dist = supportFunc(R.timePoint.set{end},hs.c,'upper') - hs.d;

            if dist < 0
                Rcont = R.timeInterval.set{end};
                break;
            elseif dist > dist_
                error('Pancake approach failed!'); 
            else
                dist_ = dist;
            end
         end 
    end
end

function options = defaultOptions(options)
% set default options for nonlinear system reachability analysis (required
% if the continuous dynamics of the hybrid automaton is linear)

    % define options and default values
    opts = {'alg','tensorOrder','errorOrder','intermediateOrder', ...
            'zonotopeOrder','taylorTerms','timeStep','intermediateTerms'};
    defVal = {'lin', 3, 5, 50, 50, 10, 0.01, 4};
    
    % parse options
    list = fields(options);
    
    for i = 1:length(list)
       if ~ismember(list{i},opts)
         options = rmfield(options,list{i});  
       end
    end
    
    for i = 1:length(opts)
        if ~isfield(options,opts{i})
            options.(opts{i}) = defVal{i};
        end
    end
end

function f = dynamicsLinSys(x,u,sys)
% dynamic function of a linear system

    if isempty(sys.c)
       f = sys.A * x + sys.B * u; 
    else
       f = sys.A * x + sys.B * u + sys.c;
    end
end
    
%------------- END OF CODE --------------