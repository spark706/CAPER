% Plot LP Results
figure; cmap = colormap(copper);
% DER Locations
[~,~,ic] = unique([{NODE.ID},{DER.ID}],'stable');
plot([NODE(ic(end-D+1:end)).XCoord],[NODE(ic(end-D+1:end)).YCoord],'sb','MarkerSize',20)
hold on

Open = true(1,S);
for i = 1:D
    % Nodes
    index = logical(round([NODE.(['a_MG',int2str(i)])]));
    plot([NODE(index).XCoord],[NODE(index).YCoord],'.',...
        'Color',cmap(floor(64/D)*(i-1)+1,:),'MarkerSize',20) %hsv2rgb([(i-1)/D .5 .5])
    
    % Loads
    index = logical(round([LOAD.(['alpha_MG',int2str(i)])]));
    plot([LOAD(index).XCoord],...
         [LOAD(index).YCoord],'^',...
        'Color',cmap(floor(64/D)*(i-1)+1,:),'MarkerSize',20)

    % Sections
    sec = logical(round([SECTION.(['b_MG',int2str(i)])]));
    Open = Open.*~sec;
    Closed = SECTION(sec);
    for j = 1:length(Closed)
        index = [find(ismember({NODE.ID},Closed(j).FROM)),find(ismember({NODE.ID},Closed(j).TO))];
        plot([NODE(index).XCoord],[NODE(index).YCoord],'-','Color',cmap(floor(64/D)*(i-1)+1,:))
    end
    
end

% Open Sections
Open = SECTION(logical(Open));

for i = 1:length(Open)
    index = [find(ismember({NODE.ID},Open(i).FROM)),find(ismember({NODE.ID},Open(i).TO))];
    plot([NODE(index).XCoord],[NODE(index).YCoord],':r','LineWidth',5)
end
