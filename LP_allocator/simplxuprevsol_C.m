
function [y0, inB, e,itlim,errout] = simplxuprevsol_C(A,ct,b,inB,h,e,m,n,itlim)
%  Bounded Revised Simplex
%
%function [yout, inBout,bout, itout,errout] = simplxuprevsol(A,ct,b,inB,inD,h,e,m,n,itlim)
%
%   Solves the linear program:
%          minimize c'y 
%          subject to 
%          Ay = b
%          0<= y <= h
%
%  Inputs: 
%          A [m,n]   = lhs Matrix of equaltity constraints
%          ct [1,n]  = transpose of cost vector
%          b [m,1]   = rhs vector for equality constraint
%          inB [m]   = Vector of indices of unknowns in the initial basic set
%          inD [n-m] = Vector of indices of unknowns not in the initial basic set
%          h[n,1]    = Upper Bound for unknowns
%          e[n,1]    = Sign for unknown variables (+ lower bound, - upper bound)
%  Optional inputs:
%          m,n       = number of constraints, unknowns (Opposite standard
%                      CA convention
%          itlim     = Upper bound on the allowed iterations\
%
% Outputs:
%         yout[n,1]  = Optimal output variable
%         inBout     = indices of Basic vectors in output
%         eout       = sign associate with output unknowns
%         itout      = number of iterations remaining out of itlim
%         errout     = Flag (=true) if unbounded is set
%
% Modification History
%   2002      Roger Beck  Original
%   8/2014    Roger Beck  Update for use
%   9/2014    Roger Beck  Added anti-cycling rule

%Optional Inputs  	
    	
%Tolerance for unknown == 0
tol=single(1e-8);

%Index list for non-basic variables
nind = (1:(n-m));

%Partition A
% #include <iostream>
% #include <set>
% #include <vector>
% 
% std::vector<int> setdiff(const std::vector<int>& a, const std::vector<int>& b) {
%     std::set<int> a_set(a.begin(), a.end());
%     std::set<int> b_set(b.begin(), b.end());
%     std::vector<int> result;
% 
%     for (int elem : a_set) {
%         if (b_set.find(elem) == b_set.end()) {
%             result.push_back(elem);
%         }
%     }
% 
%     return result;
% }
% 
% int main() {
%     std::vector<int> array1 = {1, 2, 3, 4, 5};
%     std::vector<int> array2 = {4, 5, 6, 7, 8};
% 
%     std::vector<int> diff = setdiff(array1, array2);
% 
%     for (int elem : diff) {
%         std::cout << elem << " ";
%     }
% 
%     return 0;
% }
% inD = setdiff(uint8(1:n), inB);
tmp=uint8(1:n);
 inD = tmp(~ismember(tmp, inB));

%Adjust signs problem if variables are initialized at upper
% bounds.
A(:,~e) = -A(:,~e);
ct(~e) = -ct(~e);
b = b + A(:,~e)*h(~e);

y0 = A(:,inB)\b;  %Initial Solution

%Initialize Loop Termination Conditions
done = false;
unbounded = false;

%Main Simplex loop
while (~done  || ~unbounded ) && (itlim > uint16(0))
    itlim = itlim-uint16(1);

    %Calculate transpose of relative cost vector based on current basis
    lamt = ct(inB)/A(:,inB);
    rdt = ct(inD)-lamt*A(:,inD);
    %Find minimum relative cost
    [minr, qind] = min(rdt);
    qind=uint8(qind);
    if minr >= single(0)  % If all relative costs are positive then the solution is optimal
        done = true;
        break;
    end
    qel = inD(qind);  % Unknown to Enter the basis minimizes relative cost
    yq = A(:,inB)\A(:,qel); %Vector to enter in terms of the current Basis vector
    
    if all(abs(yq)<=tol)
      unbounded = true;
      disp(' Solution is unbounded');  % Check this condition
      break
    end

    %Compute ratio how much each current basic variable will have to move for the entering
    % variable.

    rat = y0./yq; 
    
    % If yq < 0 then increasing variable when it leaves the basis will minimize cost
    hinB = h(inB);
    indm = yq<single(0);
    rat(indm) = rat(indm) - hinB(indm)./yq(indm);
    % If an element yq ~=0 then it doesn't change for the entering variable and shouldn't
    %  be chosen
    indz = abs(yq)<=tol;
    rat(indz) = inf;

    % Variable to exit is moving to its minimum value
    [minrat, p] = min(rat);

   % If the minimum ratio is zero, then the solution is degenerate and the entering
   %   variable will not change the basis---invoke Bland's selection rule to avoid
   %   cycling.
    if (abs(minrat) <= tol)
       % Find negative relative cost
       indm = nind(rdt<single(0)); %Note that since minr <0 indm is not empty   
       qind = indm(1);
       qel = inD(qind);  % Unknown to Enter the basis is first indexed to avoid cycling
       yq = A(:,inB)\A(:,qel); %Vector to enter in terms of the current Basis vector
       if all(abs(yq)<=tol)
           unbounded = true;
           disp(' Solution is unbounded');  % Check this condition
           break
       end
       % Recompute rations and determine variable to leave
       rat = y0./yq; 
        % If yq < 0 then increasing variable when it leaves the basis will minimize cost
        hinB = h(inB);
        indm = yq<single(0);
        rat(indm) = rat(indm) - hinB(indm)./yq(indm);
        % If an element yq ~=0 then it doesn't change for the entering variable and shouldn't
        %  be chosen
        indz = abs(yq)<=tol;
        rat(indz) = inf;

        % Variable to exit is moving to its minimum value--Note that min returns the lowest index minimum
        [minrat, p] = min(rat);
    end

  % Maintain the bounded simplex as only having lower bounds by recasting 
  % any variable that needs to move to its opposite bound.
    if (minrat >= h(qel))
           %Case 1: Entering variable goes to opposite bound and current basis is maintained
            e(qel) = ~e(qel);
            A(:,qel) = -A(:,qel);
             b = b + A(:,qel)*h(qel);
             ct(qel) = -ct(qel);
    elseif yq(p) > single(0)
           %Case 2: Leaving variable returns to lower bound (0)	
           pel = inB(p);
           inB(p)= qel;
           inD(qind)= pel;
     else
           %Case 2: Leaving variable moves to upper bound	
            pel = inB(p);
            e(pel)=~e(pel);
            A(:,pel) = -A(:,pel);
            inB(p)= qel;
            inD(qind)= pel;
            ct(pel) = -ct(pel);
            b = b + A(:,pel)*h(pel);
     end
        
    y0 = A(:,inB)\b; % Compute new Basic solution;
end
errout = unbounded;     
end
