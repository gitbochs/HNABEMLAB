function [I, quadDataOut] = colEvalV3(Op,fun, funSide, colPt, Nquad, quadDataIn, CGflag)

%function which evalutes integral Sf(x), essentially just a wrapper for
%NSD45 which ensures that the phase is always the analytic continuation of
%|x(s)-y(t)|

%sCol, colSide, dist2a, dist2b - all absorbed into X

    
    if nargin <= 6
        CGflag = false;
    end
    
    if CGflag
        minOscs = inf;
    else
        minOscs = 5;
    end
    %if function is defined over multiple sides, loop over these and sum up
    %contribution
    
    if length(funSide)>1
        I=0;
       for m=funSide
           if ~isempty(quadDataIn)
                [I_, ~] = colEvalV2(Op,fun, m, colPt.x, dist2b, colSide, Nquad, quadDataIn{m}, CGflag); 
           else
               [I_, quadDataOut{m}] = colEvalV2(Op,fun, m, colPt.x, dist2b, colSide, Nquad, [], CGflag); 
           end
          I = I + I_;
       end
       return;
    end
    
%     %intiialise variables for data structure:
%     z=[]; w=[]; z1a=[]; w1a=[]; z1b=[]; w1b=[];
%      split = [0 0];

    %main function:
        maxSPorder = max(Op.phaseMaxStationaryPointOrder(funSide == colPt.side), fun.phaseMaxStationaryPointOrder);
        
        kwave = Op.kwave;
        
        %get endpoints of support of function
        supp = fun.getSupp(funSide);
        a = supp(1);
        b = supp(2);
        
        %return an error if we are this close to a singularity/branch point
        dangerZoneRad = .35;%0.25/kwave;%max(0.15*(b-a),dangerWidth);
        %singularSplit = dangerZoneRad;
        
        dangerWidth = 1E-12;
      
        %analytic extension of non-osc components of kernel:
        amp_a = @(y) Op.kernelNonOscAnal(colPt.x, y, true, colPt.side, funSide) .* fun.evalNonOscAnal(y, funSide);
        amp_b = @(y) Op.kernelNonOscAnal(colPt.x, y, false, colPt.side, funSide) .* fun.evalNonOscAnal(y, funSide);
        amp_a_flip = @(r) Op.kernelNonOscAnal(r, 0, true, colPt.side, funSide).* fun.evalNonOscAnal(colPt.x - r, funSide);
        amp_b_flip = @(r) Op.kernelNonOscAnal(r, 0, true, colPt.side, funSide).* fun.evalNonOscAnal(colPt.x + r, funSide);
        %and the corresponding phases:
        phase_a = OpFunAddPhase(Op, fun, funSide, colPt.x, colPt.side, true, maxSPorder+1);
        phase_b = OpFunAddPhase(Op, fun, funSide, colPt.x, colPt.side, false, maxSPorder+1);
        %phase_b_flip = OpFunAddPhase(Op, fun, funSide, colPt.x, colPt.side, false, maxSPorder+1);
        
        for n = 1:length(phase_b)
            phase_a_flip{n} = @(r) (-1)^(n+1)*phase_a{n}(colPt.x-r);
            phase_b_flip{n} = @(r) phase_b{n}(r+colPt.x);
        end
        
        %now the more general amp, for when there is no branch in [a,b]
        amp = @(y) Op.kernelNonOscAnal(colPt.x, y, [], colPt.side, funSide) .* fun.evalNonOscAnal(y, funSide);
        phase = OpFunAddPhase(Op, fun, funSide, colPt.x, colPt.side, [], maxSPorder+1);
        
        
        if length(fun.domain.L )>1
            L = fun.domain.L(funSide);
        else
            L = fun.domain.L;
        end
            
    if funSide == colPt.side
        
        %same side singularity:
        distFun = @(t) abs(colPt.x - t);
        logSingInfo=singularity(colPt.x, Op.singularity, distFun);
        %choose the rectangle sufficiently small that phase is analytic
        rectrad = .5*min(logSingInfo.distFun(a),logSingInfo.distFun(b));
        
        if maxSPorder ==0
            SPin = [];
            SPOin = [];
        else
            SPin = NaN;
            SPOin = NaN;
        end
        
        if  a < colPt.x && colPt.x < b
            %need to split the integral, as integrand not analytic at z=x

           if ~isempty(quadDataIn)
                w1a = quadDataIn.w1a;
                w1b = quadDataIn.w1b;
                z1a = quadDataIn.z1a;
                z1b = quadDataIn.z1b;
            else
                logSingInfo_flip_a = logSingInfo;
                logSingInfo_flip_a.position = 0;
                logSingInfo_flip_a.distFun = @(r) abs(r);
                [ z1a, w1a ] = PathFinder( 0, colPt.distMeshL, kwave, Nquad, phase_a_flip,'settlerad',rectrad,...
                            'fSingularities', logSingInfo_flip_a, 'stationary points', SPin, 'order', SPOin,'minOscs',minOscs);

                logSingInfo_flip_b = logSingInfo;
                logSingInfo_flip_b.position = 0;
                logSingInfo_flip_b.distFun = @(r) abs(r);
                [ z1b, w1b ] = PathFinder(0, colPt.distMeshR, kwave, Nquad, phase_b_flip,'settlerad',rectrad,...
                            'fSingularities', logSingInfo_flip_b, 'stationary points', SPin, 'order', SPOin,'minOscs',minOscs);
                    
                quadDataOut.w1a = w1a;
                quadDataOut.w1b = w1b;
                quadDataOut.z1a = z1a;
                quadDataOut.z1b = z1b;
           end
                I1 = (w1a.'*amp_a_flip(z1a));
                I2 = (w1b.'*amp_b_flip(z1b));
                I = I1 + I2;
        else %same side, no singularity in (a,b)
            
            if colPt.x <= a
                type_ab = 'a';
                phase = phase_b;
            elseif b <= colPt.x
                type_ab = 'b';
                phase = phase_a;
            else
                %this error will probably never ever happen:
                error('cant decide which is bigger of s and t');
            end
            
            if fun.meshEl.distL <= fun.meshEl.distR
                type_LR = 'L';
                a_star = a;
                b_star = b;
                sing_star_point = colPt.x;
                phase_star = phase;
            else
                type_LR = 'R';
                a_star = fun.meshEl.distR; %= L-b;
                b_star = fun.meshEl.distR + fun.meshEl.width;  %= L-a;
                L_minus_a = b_star;
                sing_star_point = colPt.distSideR;
                for n = 1:length(phase_b)
                    phase_star{n} = @(z) (-1)^(n+1)*phase{n}(L-z);
                end
            end
            
            %create singularity info:
            logSingInfo_star = singularity(sing_star_point, Op.singularity);
            
            %there are four cases for the amp
            switch strcat(type_LR,type_ab)
                case 'La'
                    amp_star = amp_b;
                case 'Lb'
                    amp_star = amp_a;
                case 'Ra'
                    amp_star =  @(z) Op.kernelNonOscAnal(colPt.distSideR, z, true, colPt.side, funSide) .* fun.evalNonOscAnalPivot(z, funSide, L_minus_a);
                case 'Rb'
                    amp_star =  @(z) Op.kernelNonOscAnal(colPt.distSideR, z, false, colPt.side, funSide) .* fun.evalNonOscAnalPivot(z, funSide, L_minus_a);
            end
            
            if ~isempty(quadDataIn)
                w_ = quadDataIn.w_;
                z_ = quadDataIn.z_;
            else
                %now get weights and nodes:
                [ z_, w_ ] = PathFinder( a_star, b_star, kwave, Nquad, phase_star,'settlerad',rectrad,...
                        'fSingularities', logSingInfo_star, 'stationary points', SPin, 'order', SPOin, 'minOscs', minOscs, 'width', fun.suppWidth);
                    
                quadDataOut.w_ = w_;
                quadDataOut.z_ = z_;
            end
                
            %and evaluate integral:
            I = w_.'*amp_star(z_);
            %now store in correct form:
            if colPt.x <= a
                w1b = w_;
                z1b = z_;
            else
                w1a = w_;
                z1a = z_;
            end
        end
    else %no branch in phase
        
%         I = integral(@(z) amp(z).*exp(1i*kwave*phase{1}(z)), a, b, 'arrayValued', true,'RelTol',1e-13);
%         quadDataOut = [];
%         return;

        quadDataOut = [];
        [stationaryPoints, orders, branchPoints] = symbolicStationaryPoints(Op.domain.side{colPt.side}.trace(colPt.x), fun, funSide, phase);
        
        SPin = stationaryPoints;
        SPOin = orders;
        
        %determine if endpoint is close to singularity on neighbouring
        %side:
        
        if min(abs(a-branchPoints(1)),abs(a-branchPoints(2))) < dangerZoneRad
            singClose2a = true;
        else
            singClose2a = false;
        end
        
        if min(abs(b-branchPoints(1)),abs(b-branchPoints(2))) < dangerZoneRad
            singClose2b = true;
        else
            singClose2b = false;
        end
        
        grad2a = false; grad2b = false;
        if singClose2a
            if a>L/2
                grad2b = true;
            else
                grad2a = true;
            end
        elseif singClose2b
            if b<L/2
                grad2a = true;
            else
                grad2b = true;
            end
        end
        
        if ~grad2a && ~ grad2b %no singularity issues
            
            if ~isempty(quadDataIn)
                %load quad data and skip to the sum
                z = quadDataIn.z;
                w = quadDataIn.w;
            else
                if isa(fun,'GeometricalOpticsFunction')
                    width = fun.suppWidth(funSide);
                else
                    width = fun.suppWidth;
                end
                distFun = @(t) Op.domain.distAnal(colPt.x, t, 0, [], colPt.side, funSide);
                %distR = Op.domain.distAnal(colPt.x, b, 0,[], colPt.side, funSide);
                logSingInfo=singularity([], Op.singularity, distFun);
                rectrad = .5*min(logSingInfo.distFun(a),logSingInfo.distFun(b));
                if width<minOscs*2*pi/kwave
                    [ z, w ] = PathFinder( a, b, kwave, Nquad, phase, ...
                                            'stationary points', stationaryPoints, 'order', orders, 'settlerad', ...
                                                rectrad,'minOscs',inf, 'width', width);
                                            %have changed minOscs to inf, to
                                            %always use standard quad here ^^
                    %I = (w.'*amp(z));
                else

                    if ~isempty(stationaryPoints)
                        if  ~(a <= stationaryPoints && stationaryPoints <= b)
                            stationaryPoints = [];
                            orders = [];
                        end
                    end
                    if isempty(stationaryPoints)
                        %perhaps the phase is flat near the endpoints, so chop
                        %off the first few oscillations:
                        XoscL = findNonOscBit(phase{1},a,b,kwave,minOscs);
                        XoscR = findNonOscBitR(phase{1},a,b,kwave,minOscs);
                        if XoscR<XoscL
                            %do the whole thing non-oscilllatorily
                            [ z, w ] = PathFinder( a, b, kwave, Nquad, phase, ...
                                            'stationary points', stationaryPoints, 'order', orders, 'settlerad', ...
                                                rectrad,'minOscs',inf, 'width', width);
                        else
                            [ za, wa ] = PathFinder( a, XoscL, kwave, Nquad, phase, ...
                                            'stationary points', stationaryPoints, 'order', orders, 'settlerad', ...
                                                rectrad,'minOscs',inf, 'width', width);

                            [ z_mid, w_mid ] = PathFinder( XoscL, XoscR, kwave, Nquad, phase, ...
                                            'stationary points', stationaryPoints, 'order', orders, 'settlerad', ...
                                                rectrad,'minOscs',minOscs, 'width', width);
                            [ zb, wb ] = PathFinder( XoscR, b, kwave, Nquad, phase, ...
                                            'stationary points', stationaryPoints, 'order', orders, 'settlerad', ...
                                               rectrad,'minOscs',inf, 'width', width);
                             z = [za; z_mid; zb];
                             w = [wa; w_mid; wb];
                        end
                        %I = PathFinderChebWrap(a,b,kwave,Nquad,amp,phase,logSingInfo,stationaryPoints);
                    else% a <= stationaryPoints && stationaryPoints <= b
                         [ z, w ] = PathFinder( a, b, kwave, Nquad, phase, ...
                                            'stationary points', stationaryPoints, 'order', orders, 'settlerad', ...
                                                rectrad,'minOscs',minOscs, 'width', width);
                    end
                end
                %save quad data
                quadDataOut.z = z;
                quadDataOut.w = w;
            end
            
            I = (w.'*amp(z));
            return;
        end
        
        if grad2a
            if isa(fun,'GeometricalOpticsFunction')
                a_shift = 0;
                b_shift = fun.suppWidth(funSide);
                width = fun.suppWidth(funSide);
            else
                a_shift = fun.meshEl.distL; %want dista
                b_shift = fun.meshEl.distL + fun.suppWidth;
                width = fun.suppWidth;
            end
            suppDistCorner = a_shift;
            
            colDistCorner = colPt.distSideR;
            
            amp_corner = @(y) Op.kernelNonOscAnalCorner( colPt.distSideR, y, a_shift, colPt.side, funSide) .* fun.evalNonOscAnal( a + y, funSide); %changed from (a_shift +y, funSide);
            phaseCorner = OpFunAddPhaseCorner(Op, fun, funSide, colPt.distSideR, a_shift, colPt.side, maxSPorder+1 , a, false);
            
            
        elseif grad2b
            if isa(fun,'GeometricalOpticsFunction')
                a_shift = 0;
                b_shift = fun.suppWidth(funSide);
                width = fun.suppWidth(funSide);
            else
                a_shift = fun.meshEl.distR;
                b_shift = fun.meshEl.distR + fun.suppWidth;
                width = fun.suppWidth;
            end
            suppDistCorner = a_shift;
            
            colDistCorner = colPt.distSideL;
            
            amp_corner = @(y) Op.kernelNonOscAnalCorner( colPt.distSideL, y, a_shift, colPt.side, funSide).* fun.evalNonOscAnal( b - y, funSide);  %changed from (a_shift -y, funSide);
            phaseCorner = OpFunAddPhaseCorner(Op, fun, funSide, colPt.distSideL, a_shift, colPt.side, maxSPorder+1 , b, true);
        end
        
            %determine the location of the singularities after this change
            %of variables
            internalAngle = Op.domain.internalAngle(colPt.side,funSide);
            %sing_flip = mean(roots([1,2*suppDistCorner - 2*colDistCorner*cos(internalAngle),suppDistCorner^2 + colDistCorner^2 -2*suppDistCorner*colDistCorner*cos(internalAngle)]));
            [SP_flip4, orders4, sing_flip] = symbolicStationaryPointsCorner(colDistCorner, suppDistCorner, fun, internalAngle, funSide, phaseCorner);
            real_sing_flip = mean(sing_flip);
            
            %construct singularity data
            R = @(yr) sqrt(colDistCorner^2 + (suppDistCorner + yr).^2 - 2*cos(internalAngle)*colPt.distSideL*(suppDistCorner + yr));
            logSingInfo_flip = singularity(real_sing_flip, Op.singularity, R);
            rectRad = .5*min(logSingInfo_flip.distFun(a_shift), logSingInfo_flip.distFun(b_shift));
            
            %now remove stationary points that are far away from
            %integration region:

            Xoscs = findNonOscBit(phaseCorner{1},0,width,kwave,minOscs);
            logSingInfo_flip_1.position = real(sing_flip(1));
            logSingInfo_flip_1.blowUpType='nearLog';
            logSingInfo_flip_1.distFun = @(r) abs(r-sing_flip(1));

            [x_, w_] = NonOsc45(0,Xoscs,kwave,Nquad,phaseCorner{1},logSingInfo_flip_1,Xoscs);
            I_1 = (w_.'*amp_corner(x_));
            if Xoscs>=width
                I_2 = 0;
            elseif ~isempty(SP_flip4)
                if SP_flip4<Xoscs
                    I_2 = PathFinderChebWrapGrad(logSingInfo_flip, Xoscs, width, kwave, Nquad, amp_corner, phaseCorner);
                else
                    if abs(sing_flip(1) - Xoscs) < dangerWidth
                        error('Singularity dangerously close and not being acknowledged');
                    end
                    if ~isempty(quadDataIn)
                        z = quadDataIn.z;
                        w = quadDataIn.w;
                    else
                        [ z, w ] = PathFinder( Xoscs, width, kwave, Nquad, phaseCorner,...
                                        'stationary points', SP_flip4, 'order', orders4, 'settlerad', ...
                                            rectRad, 'minOscs', minOscs, 'width', width);
                        quadDataOut.z = z;
                        quadDataOut.w = w;
                    end
                    I_2 = (w.'*amp_corner(z));
                end
            else
                I_2 = PathFinderChebWrapGrad(logSingInfo_flip,Xoscs,width,kwave,Nquad,amp_corner,phaseCorner);
            end
            I = I_1 + I_2;
    end
    
%    quadDataOut = struct('z',z,'w',w,'split',split,'z1a', z1a, 'w1a',w1a,'z1b', z1b, 'w1b', w1b);
            
end