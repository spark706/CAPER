function LOOPS = findLoops(SECTION)

% Find Open Points
NormOpen = SECTION(~logical([SECTION.NormalStatus]));

for i = 1:length(NormOpen)
    from = NormOpen(i).FROM;
    to   = NormOpen(i).TO;
    
    % find adjacent sections
    index1 = find(ismember({SECTION.FROM},to));
    index2 = find(ismember({SECTION.TO},to));
    adj = [{SECTION(index1).TO},{SECTION(index2)}];


end
end