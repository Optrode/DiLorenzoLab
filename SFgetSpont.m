function [ spontIntervals ] = SFgetSpont( intervalTimes, exclWin, endTime )
%%
% intervalTimes is a Nx2 matrix, where N = number of stimulus intervals

intervalTimes = sortrows(intervalTimes, 1);

intervalTimes = intervalTimes + [-exclWin, exclWin];

newStimWindows = [];

while 1
    if isempty(intervalTimes)
       break 
    end
    ovlInd = intervalTimes(:,1) <= intervalTimes(1,2);
    intervalTimes(1,2) = max(intervalTimes(ovlInd,2));
    newStimWindows = [newStimWindows; intervalTimes(1,:)];
    intervalTimes(ovlInd,:) = [];
end



if newStimWindows(1,1)>0
    spontIntervals = [0, newStimWindows(1,1)];
else
    spontIntervals = [];
end

spontIntervals = [spontIntervals; [newStimWindows(1:end-1,2), newStimWindows(2:end,1)] ];

if newStimWindows(end,2) < endTime
    spontIntervals = [spontIntervals; [newStimWindows(end,2), endTime] ];
end

%%

end