function [f,intcon,Aineq,bineq,Aeq,beq,lb,ub] = ResiliencyMILPForm(NODE,SECTION,LOAD,DER,PARAM)
% N                 - NODE.ID
% S                 - (SECNTION.FROM,SECTION.TO)
% D                 - DER.ID
% w                 - NODE.w
% p                 - NODE.p
% q                 - NODE.q
% KVAmax_d          - DER.CAPACITY
% alpha             - 1
eta = 1;
pf = 0.85;
M = 5;

N = length(NODE);       % Number of Nodes
S = length(SECTION);    % Number of Sections
D = length(DER);        % Number of DER
L = length(LOAD);       % Number of Loads

%%
%            max                    sum(w_i * sum(c_id*p_i))
% a,alpha,b,bbar,beta,c,gamma       i<N       d<D

% Let x = [a;alpha;b;bbar;c;gamma], then
% a     = x[       1      :       n      ]
% alpha = x[      n+1     :    (d+1)*n   ]
% b     = x[   (d+1)*n+1  :   (d+1)*n+s  ]
% bbar  = x[    (d+1)*n+s+1 :   (d+1)*n+2s ]
% beta  = x[   (d+1)*n+2s+1 : (d+1)*n+(2+d)s  ]
% c     = x[ (d+1)*n+(2+d)s+1  :  (d+1)n+2s ]
% gamma = x[  (d+1)n+2s+1 : (2d+1)n+2s ]

% Define starting indicies
a       = 0;
alpha   = a+N;
b       = alpha+D*N;
bbar    = b+S;
beta    = bbar+S;
c       = beta+D*S;
gamma   = c+L*D;

f_a     = zeros(N,1);
f_alpha = zeros(D*N,1);
f_b     = zeros(S,1);
f_bbar  = ones(S,1);
f_beta  = zeros(D*S,1);
f_c     = -repmat([LOAD.w]'.*[LOAD.p]',D,1);
f_gamma = zeros(D,1);

f = [f_a;f_alpha;f_b;f_bbar;f_beta;f_c;f_gamma];

xlen = length(f);

%% Set variable bounds/binary constraints
% All Variables are binary
lb = zeros(xlen,1);
ub = ones (xlen,1);
intcon = 1:xlen;

%%  Constraints
% -DSCC-(1)-to-(4)---------------------------------------------------------
% (1) Nodes constrained open      (a_i = 0 Vi<NO)       ---UNUSED---
% (2) Nodes constrained closed    (a_i = 1 Vi<NC)       ---FIX CP---
% (3) Sections constrained open   (b_ij = 0 V(i,j)<SO)  ---FAULTS---
% (4) Sections constrained closed (b_ij = 1 V(i,j)<SC)  ---NO SWI---

NO = length(PARAM.NO);
NC = length(PARAM.NC);
SO = length(PARAM.SO);
SC = length(PARAM.SC);

% Remove Duplicates
[~,~,ic] = unique([PARAM.SC,PARAM.SO],'stable');
index = ic(end-SO+1:end);
PARAM.SC(:,index(index<SC)) = [];
SC = length(PARAM.SC);

[~,~,ic] = unique([PARAM.NC,PARAM.NO],'stable');
index = ic(end-NO+1:end);
PARAM.SC(:,index(index<NC)) = [];
NC = length(PARAM.NC);

b1 = zeros(NO,1);
b2 = ones (NC,1);
b3 = zeros(SO,1);
b4 = ones (SC,1);

A1 = zeros(NO,xlen);
A2 = zeros(NC,xlen);
A3 = zeros(SO,xlen);
A4 = zeros(SC,xlen);

for i = 1:NO
    % Find index of constrained node
    index = find(ismember({NODE.ID},PARAM.NO{i}));
    
    A1(i,a+index) = 1; % coeff for a_i (1)
end

for i = 1:NC
    % Find index of constrained node
    index = find(ismember({NODE.ID},PARAM.NC{i}));
    
    A2(i,a+index) = 1; % coeff for a_i (2)
end

for i = 1:SO
    % Find index of constrained section
    index = find(ismember({SECTION.ID},PARAM.SO{i}));
    
    A3(i,b+index) = 1; % coeff for b_ij (3)
end

for i = 1:SC
    % Find index of constrained section
    index = find(ismember({SECTION.ID},PARAM.SC{i}));
    
    A4(i,b+index) = 1; % coeff for b_ij (4)
end

% -DSCS-(6)-to-(9)----------------------------------------------------------
% (6)    bbar_ij - b_ij <= n_ij       all (i,j) in S
% (7) -( bbar_ij - b_ij ) <= n_ij     all (i,j) in S
% (8) -( bbar_ij + b_ij ) <= - n_ij   all (i,j) in S
% (9)    bbar_ij + b_ij <= 2 - n_ij   all (i,j) in S

b6 = [SECTION.NormalStatus]';
b7 = [SECTION.NormalStatus]';
b8 = -[SECTION.NormalStatus]';
b9 = 2*ones(S,1)-[SECTION.NormalStatus]';

A6 = zeros(S,xlen);
A6(:,bbar+1:bbar+S) = eye(S); % coeff for beta_ij (6)
A9 = A6; % coeff for beta_ij (9)
A6(:,b+1:b+S) = -eye(S); % coeff for b_ij (6)
A7 = sparse(-A6); % coeff for beta_ij, b_ij (7)
A9(:,b+1:b+S) = eye(S); % coeff for b_ij (9)
A8 = sparse(-A9); % coeff for beta_ij, b_ij (8)

A6 = sparse(A6);
A9 = sparse(A9);

% -MCC-(10)-&-(11)---------------------------------------------------------
% (10) gamma_g - sum( alpha_dg ) <= 0  all g in G
%                d<D
% (11) alpha_dg - gamma_g        <= 0  all g in G, d in D


[~,~,ic] = unique([{NODE.ID},{DER.ID}],'stable');
der = ic(end-D+1:end);

b10 = sparse([],[],[],D,1);

i10 = reshape(repmat(1:D,D+1,1),[],1);
j10 = reshape([gamma+(1:D);alpha+repmat(der,1,D)+repmat(0:N:D*N-1,D,1)],[],1);
v10 = repmat([1;-ones(D,1)],D,1);
A10 = sparse(i10,j10,v10,D,xlen);


b11 = sparse([],[],[],D*D,1);
    
i11 = reshape(repmat(1:D*D,2,1),[],1);
j11 = reshape([reshape(alpha+repmat(der,1,D)+repmat(0:N:D*N-1,D,1),[],1),...
    reshape(repmat(gamma+(1:D),D,1),[],1)]',[],1);
v11 = repmat([1;-1],D*D,1);
A11 = sparse(i11,j11,v11,D*D,xlen);


% -MCC-(13)-to-(15)--------------------------------------------------------
% (13)  c_ig - alpha_ig <= 0         all i in L, g in G
% (14)  c_ig - a_i <= 0              all i in L, g in G
% (15) -c_ig + alpha_ig + a_i <= 1   all i in L, g in G

b13 = sparse([],[],[],L*D,1); 
b14 = sparse([],[],[],L*D,1);
b15 = ones (L*D,1);

[~,~,ic] = unique([{NODE.ID},{LOAD.ID}],'stable');
index = ic(N+1:N+L);

i13 = reshape(repmat(1:L*D,2,1),[],1);
j13 = reshape([c+(1:L*D);...
    alpha+reshape(repmat(index,1,D)+repmat(N*(0:D-1),L,1),1,[])],[],1);
v13 = repmat([1;-1],L*D,1);
A13 = sparse(i13,j13,v13,L*D,xlen);

i14 = reshape(repmat(1:L*D,2,1),[],1);
j14 = reshape([c+(1:L*D);...
    a+repmat(index',1,D)],[],1);
v14 = repmat([1;-1],L*D,1);
A14 = sparse(i14,j14,v14,L*D,xlen);

i15 = reshape(repmat(1:L*D,3,1),[],1);
j15 = reshape([c+(1:L*D);...
    alpha+reshape(repmat(index,1,D)+repmat(N*(0:D-1),L,1),1,[]);...
    a+repmat(index',1,D)],[],1);
v15 = repmat([-1;1;1],L*D,1);
A15 = sparse(i15,j15,v15,L*D,xlen);


%{
A13 = zeros(D*N,xlen);
A13(:,c+1:c+D*N) = eye(D*N); % coeff for c_id (13)
A14 = A13; % coeff for c_id (14)
A14(:,a+1:a+N) = repmat(-eye(N),D,1); % coeff for a_i (14)
A13(:,gamma+1:gamma+D*N) = -eye(D*N); % coeff for gamma_id (13)
A15 = -A13; % coeff for c_id, gamma_id (15)
A15(:,a+1:a+N) = repmat(eye(N),D,1); % coeff for a_i (15)
%}

% -MCC-(16)----------------------------------------------------------------
% (16) eta * sum( c_ig p_i) - sum( alpha_dg KVAmax_d ) <= 0    all g in G
%            i<L              d<D

b16 = sparse([],[],[],D,1);

[~,~,ic] = unique([{NODE.ID},{DER.ID}],'stable');
index = ic(end-D+1:end);

i16 = [reshape(repmat(1:D,L,1),[],1);reshape(repmat(1:D,D,1),[],1)];
j16 = [c+(1:D*L)';alpha+reshape(repmat(N*(0:D-1),D,1)+repmat(index,1,D),[],1)];
v16 = [repmat(eta*[LOAD.p]'/pf,D,1);repmat(-[DER.CAPACITY]',D,1)];
A16 = sparse(i16,j16,v16,D,xlen);

%{
A16 = zeros(D,xlen);

temp = eta*[LOAD.p]/pf;
for i = 1:D
    A16(i,c+(i-1)*L+1:c+i*L) = temp;  % coeff for c_ig,  g constant (16)
    A16(i,alpha+(i-1)*N+index) = -[DER.CAPACITY]; % coeff for alpha_dg,  g constant (16)
end
clear temp
%}


% -MCC-(17)-&-(18)---------------------------------------------------------
% (17) sum( alhpa_ig ) <= 1   all i in N
%      g<G
% (18) sum( beta_ijg ) <= 1   all (i,j) in S
%      g<G

b17 = ones(N,1);
b18 = ones(S,1);

i17 = reshape(repmat(1:N,D,1),[],1);
j17 = reshape(alpha+repmat(N*(0:D-1)',1,N)+repmat(1:N,D,1),[],1);
v17 = ones(D*N,1);
A17 = sparse(i17,j17,v17,N,xlen);

i18 = reshape(repmat(1:S,D,1),[],1);
j18 = reshape(beta+repmat(S*(0:D-1)',1,S)+repmat(1:S,D,1),[],1);
v18 = ones(D*S,1);
A18 = sparse(i18,j18,v18,S,xlen);

% -MCC-(20)-to-(24)--------------------------------------------------------
% (20)    beta_ijg - b_ij              <= 0   all (i,j) in S, g in G
% (21)    beta_ijg - alpha_ig          <= 0   all (i,j) in S, g in G
% (22)    beta_ijg - alpha_jg          <= 0   all (i,j) in S, g in G
% (23) -( beta_ijg - alpha_ig ) + b_ij <= 1   all (i,j) in S, g in G
% (24) -( beta_ijg - alpha_jg ) + b_ij <= 1   all (i,j) in S, g in G

b20 = sparse([],[],[],D*S,1);
b21 = sparse([],[],[],D*S,1);
b22 = sparse([],[],[],D*S,1);
b23 = ones(D*S,1);
b24 = ones(D*S,1);


i20 = reshape(repmat(1:D*S,2,1),[],1);
j20 = reshape([beta+(1:D*S);repmat(b+(1:S),1,D)],[],1);
v20 = repmat([1;-1],D*S,1);
A20 = sparse(i20,j20,v20,D*S,xlen);

[~,~,ic] = unique([{NODE.ID},{SECTION.FROM}],'stable');
index = ic(N+1:N+S);

i21 = reshape(repmat(1:D*S,2,1),[],1);
j21 = reshape([beta+(1:D*S);...
    alpha+reshape(repmat(index,1,D)+repmat(N*(0:D-1),S,1),1,[])],[],1);
v21 = repmat([1;-1],D*S,1);
A21 = sparse(i21,j21,v21,D*S,xlen);

i23 = reshape(repmat(1:D*S,3,1),[],1);
j23 = reshape([beta+(1:D*S);...
    alpha+reshape(repmat(index,1,D)+repmat(N*(0:D-1),S,1),1,[]);...
    b+repmat(1:S,1,D)],[],1);
v23 = repmat([-1;1;1],D*S,1);
A23 = sparse(i23,j23,v23,D*S,xlen);


[~,~,ic] = unique([{NODE.ID},{SECTION.TO}],'stable');
index = ic(N+1:N+S);

i22 = reshape(repmat(1:D*S,2,1),[],1);
j22 = reshape([beta+(1:D*S);...
    alpha+reshape(repmat(index,1,D)+repmat(N*(0:D-1),S,1),1,[])],[],1);
v22 = repmat([1;-1],D*S,1);
A22 = sparse(i22,j22,v22,D*S,xlen);

i24 = reshape(repmat(1:D*S,3,1),[],1);
j24 = reshape([beta+(1:D*S);...
    alpha+reshape(repmat(index,1,D)+repmat(N*(0:D-1),S,1),1,[]);...
    b+repmat(1:S,1,D)],[],1);
v24 = repmat([-1;1;1],D*S,1);
A24 = sparse(i24,j24,v24,D*S,xlen);


% -MCC-(25)----------------------------------------------------------------
% (25) alpha_ig - sum( beta_kig ) - sum( beta_ikg ) <= 0  all i in N/D, g in G
%               (k,i)<S           (i,k)<S

%b25 = sparse([],[],[],(N-D)*D,1);
b25 = sparse([],[],[],N*D,1);


i25 = [0];
j25 = [];
v25 = [];

for i = 1:N
    %if ~sum(ismember({DER.ID},NODE(i).ID)) % Exclude DER Nodes
        index = [find(ismember({SECTION.FROM},NODE(i).ID)),find(ismember({SECTION.TO},NODE(i).ID))];
        count = length(index);
        j25 = [j25;reshape([alpha+i+N*(0:D-1);beta+repmat(index',1,D)+repmat(S*(0:D-1),count,1)],[],1)];
        i25 = [i25;reshape(repmat((i25(end)+1:i25(end)+D),count+1,1),[],1)];
        v25 = [v25;repmat([1;-ones(count,1)],D,1)];
%     else
%         disp('HIT')
    %end
end
i25(1) = [];

%A25 = sparse(i25,j25,v25,(N-D)*D,xlen);
A25 = sparse(i25,j25,v25,N*D,xlen);

% -RSC-(26)-&-(27)---------------------------------------------------------
% (26) sum( alpha_ig ) - sum( beta_ijg ) - gamma_g = 0                         all g in G
%      i<N             (i,j)<S
% (27) sum( sum( alpha_ig ) ) - sum( sum( beta_ijg ) ) - sum( gamma_g ) = 0
%      i<N  i<N                 g<G (i,j)<S              g<G
% (REDUNDANT??)

b26 = sparse([],[],[],D,1);
%b27 = sparse([],[],[],1,1);

i26 = reshape(repmat(1:D,N+S+1,1),[],1);
j26 = reshape([alpha+repmat(1:N,D,1)+repmat(N*(0:D-1)',1,N),...
    beta+repmat(1:S,D,1)+repmat(S*(0:D-1)',1,S),...
    gamma+(1:D)']',[],1);
v26 = repmat([ones(N,1);-ones(S+1,1)],D,1);
A26 = sparse(i26,j26,v26,D,xlen);

% i27 = 
% j27 = 
% v27 =
% A27 = sparse(i27,j27,v27,1,xlen);


Aineq = [A6;A7;A8;A9;A10;A11;A13;A14;A15;A16;A17;A18;A20;A21;A22;A23;A24;A25];
bineq = [b6;b7;b8;b9;b10;b11;b13;b14;b15;b16;b17;b18;b20;b21;b22;b23;b24;b25];

Aeq = [A1;A2;A3;A4;A26];        %;A27];
beq = [b1;b2;b3;b4;b26];        %;b27];