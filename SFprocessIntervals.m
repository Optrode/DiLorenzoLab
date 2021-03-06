Q = obxq(obx, 'units', 'rat, title, scid, sid, uid, channel, unum', 'date = ''2018-02-06'' AND unitcat = 3 AND cpxevents IS NOT NULL');
% Q = obxq(obx, 'units', 'rat, title, scid, sid, channel, spkcode', 'date =''2018-02-06 ''');
Q.rownum = (1:height(Q)).';
Q = Q(:,[end 1:end-1])
chpick = input('Pick unit:  ')
spk = table2struct(obxq(obx, 'chans', 'ts, wf, finalunits, cpxevents, plxevents, maxt', ['scid = ' num2str(Q.scid(chpick))]));
endtime = (spk.maxt/1000) - 10;

% Ts = (spk.ts{1})/1000; %Convert to seconds
% units = spk.finalunits; %index units
sts = spk.ts(spk.finalunits == Q.unum(chpick))./1000;

if height(spk.cpxevents.intervals)<=1
    disp('Event Issue');
end
%% PARAMETERS
excluWin = .5; %% stops trial interval bleed in
binSize = .1;

%% Make table of all individual intervals
evtable = spk.cpxevents.intervals;
tblExpand = @(X,Y,Z) table(repmat(cellstr(X),numel(Y),1), Y, Z);
evtable = cellfun(tblExpand, nexevtable.name, nexevtable.intStarts, nexevtable.intEnds, 'UniformOutput', false);
evtable = cat(1,evtable{:});
evtable.Properties.VariableNames = {'name', 'tstart', 'tend'};
evtable.name = string(evtable.name);
evtable(evtable.name == "AllFile",:) = [];

% Get spontaneous intervals
spontIntervals = SFgetSpont([evtable.tstart, evtable.tend], excluWin, endtime);



% And add them to 'evtable'
evtable((height(evtable)+1):(height(evtable)+size(spontIntervals,1)),:) = table(repmat("Spontaneous", size(spontIntervals,1), 1), spontIntervals(:,1), spontIntervals(:,2));


%% Make table of interval types 
%%%%%%% IMPORTANT!  READ BELOW! %%%%%%
% This section will need to be adapted, depending on exactly how the
% intervals are named.  The procedure used below will work accurately for
% the recording it was tested on, "NRF7 2018-02-06 SP SF".  Before being
% used for other SF recordings, it will certainly need to be updated to
% work with SF recordings that have different naming conventions.


stims = table;
stims.name = unique(evtable.name);
stims.index = [1:height(stims)].';

% Use regexp to attempt to find which variable names contain "Well"
well_regex = "w(ell)?_";
stims.wellvar = ~ismissing(regexpi(stims.name, well_regex,  'match', 'once', 'emptymatch'));
stims.food = strings(height(stims),1);
stims.food(stims.wellvar) = regexprep(stims.name(stims.wellvar), well_regex, "", 'ignorecase');

% The best way I can find to identify food variables is by elimination,
% i.e. setting "foodvar" to true and then setting it to false for all the
% things I know AREN'T food intervals.  This is a shitty stopgap solution.
stims.foodvar = true(height(stims),1);
stims.foodvar(stims.wellvar) = false; % Well intervals are not food intervals
stims.foodvar(stims.name == "Spontaneous") = false; % Spont intervals are not food intervals
stims.foodvar(stims.name == "Grooming") = false; % Grooming intervals are not food intervals.


evtable.well(ismember(evtable.name, stims.name(stims.wellvar))) = true;
evtable.food(ismember(evtable.name, stims.name(stims.foodvar))) = true;


%% Merge intervals of same type with less than excluWin space between them
x = 1;
while x<height(evtable)
    mergeInts = (evtable.name == evtable.name(x)) & (evtable.tstart > evtable.tstart(x)) & ((evtable.tstart - evtable.tend(x))<= excluWin);
    if any(mergeInts)
        evtable.tend(x) = max(evtable.tend(mergeInts));
        evtable(mergeInts,:) = [];
    else
        x=x+1;
    end
end


evtable = sortrows(evtable, 'tstart', 'ascend');
%
trimmedInts = table;
while 1
    
    % If done, break out of loop
    if isempty(evtable)
        break
    end
    
    % If the current interval has been 'flipped' by a preceding interval
    % butting in, delete it and continue on to next interval
    if (evtable.tend(1) - evtable.tstart(1)) < binSize
        evtable(1,:) = [];
        continue
    else
        evtable((evtable.tend - evtable.tstart)<binSize,:) = [];
    end
    
    % If no other intervals begin during the current interval (i.e. overlap)
    if all(evtable.tstart(2:end) > evtable.tend(1))
        if height(evtable)>1
            evtable.tend(1) = min(evtable.tend(1), evtable.tstart(2)-excluWin);
        end
        trimmedInts = [trimmedInts; evtable(1,:)];
        evtable(1,:) = [];
    else % But, if one or more intervals DO begin within the current interval...
        
        % If there is at least one bin before an overlapping interval begins, add that interval to new interval list
        if ((evtable.tstart(2)-excluWin) - evtable.tstart(1)) > binSize
            trimmedInts = [trimmedInts; evtable(1,:)];
            trimmedInts.tend(end) = evtable.tstart(2)-excluWin;
        end
        
        % If the overlapping interval does not end within the current
        % interval...
        if evtable.tend(2) > evtable.tend(1)
            evtable.tstart(2) = evtable.tend(1) + excluWin; % Then move that interval's start up...
            evtable(1,:) = []; % And terminate the current interval, then move on to the next.
        else % But if the overlapping interval DOES end...
            evtable.tstart(1) = evtable.tend(2) + excluWin; % Then the current interval can pick back up where the overlapping interval leaves off.            
            evtable(2,:) = []; % The entirety of the overlapping interval is, of course, unusable.
            evtable.tstart = max(evtable.tstart, evtable.tstart(1)); % Update any other overlapping intervals to start at the same time
        end
        
    end
end

evtable = trimmedInts;
clear('trimmedInts');
evtable((evtable.tend - evtable.tstart)<binSize,:) = []; % Trim any remaining 'flipped' intervals


% Add duration, just because
evtable.duration = evtable.tend - evtable.tstart;

% Get spike counts for each interval, just because
evtable.scount = arrayfun(@(X,Y) histcounts(sts(sts>=X & sts<=Y), X:binSize:Y).', evtable.tstart, evtable.tend, 'UniformOutput', false);

% Get mean spikerates, just because
evtable.meanSpkrate = cellfun(@mean, evtable.scount);

% Count how many intervals there are for each stimulus
stims.count = cellfun(@(X) sum(evtable.name == X), stims.name);

% Retrieve the bin counts for each stimulus from evtable
stims.allcounts = cellfun(@(X) cat(1,evtable.scount{evtable.name == X}), stims.name, 'UniformOutput', false);

% You can then do further analyses on the counts, as desired
% Also, this should REALLY be turned into a function soon