clear
clc
close all

%% DAQ start

d = daqlist;
d(1,:)

dq = daq("ni");
dq.Rate = 100;
addoutput(dq, "myDAQ1", "ao0", "Voltage");
ai0 = addinput(dq, "myDAQ1", "ai0", "Voltage");
ai0.TerminalConfig = 'Differential';

% Setup digital outputs separately
dqDigital = daq("ni");
addoutput(dqDigital, "myDAQ1", 'port0/line0', "Digital");
addoutput(dqDigital, "myDAQ1", 'port0/line1', "Digital");
addoutput(dqDigital, "myDAQ1", 'port0/line2', "Digital");
addinput(dqDigital,"myDAQ1", 'port0/line3', "Digital");
addinput(dqDigital,"myDAQ1", 'port0/line4', "Digital");
addinput(dqDigital,"myDAQ1", 'port0/line5', "Digital");
addinput(dqDigital,"myDAQ1", 'port0/line6', "Digital");

dq.ScansAvailableFcn = @(src, evt) getData(src, evt, dqDigital);
dq.ScansAvailableFcnCount = dq.Rate / 10;

%% Set constant voltage output
Vout = 10;
out = Vout * ones(1, dq.Rate); % Generate 1 second of data

%% Voltage init
preload(dq, out')
start(dq, "repeatoutput")

%% Function declaration
function getData(src, ~, dqDigital)
    persistent dataBuffer max min range expansionThresh smallOcclusionThresh mediumOcclusionThresh largeOcclusionThresh

    if isempty(dataBuffer)
        dataBuffer = [];
        max = 0.62; % occlusion
        min = -0.05; % expansion
        range = max - min;
        expansionThresh = 0.05;
        smallOcclusionThresh = 0.2;
        mediumOcclusionThresh = 0.45;
        largeOcclusionThresh = 0.7;
    end

    [data, ~] = read(src, src.ScansAvailableFcnCount, "OutputFormat", "Matrix");
        
    % Append new data to the buffer
    dataBuffer = [dataBuffer; data(:, 1)];

    % Limit buffer to 1 seconds worth of data
    maxBufferSize = 0.05 * src.Rate; % 1 seconds worth of data
    if length(dataBuffer) > maxBufferSize
        dataBuffer = dataBuffer(end-maxBufferSize+1:end);
    end
    
    % Calculate moving average
    movingAverage = mean(dataBuffer);
    % percentage = (movingAverage - min)/range;

    percentage = (data(:, 1) - min)/range;

    % percentage = data(:, 1);

    % % Exponential moving average calculation
    % n = 12;
    % alpha = 2 / (n + 1);
    % for i = 1:length(data(:, 1))
    %     percentage = alpha * (data(i, 1) - min) / range + (1 - alpha) * percentage;
    % end
    
    disp((percentage * range) + min)
    
    % Read digital input for feedback control
    digitalInput = read(dqDigital, "OutputFormat", "Matrix");
    expansion = digitalInput(:, 1); % Reading port0/line3
    occlusion_small = digitalInput(:, 2); % Reading port0/line4
    occlusion_medium = digitalInput(:, 3); % Reading port0/line5
    occlusion_large = digitalInput(:, 4); % Reading port0/line6
    
    % Feedback control logic
    if occlusion_large
        disp("large occlusion")
        if percentage < largeOcclusionThresh
            write(dqDigital, [1, 1, 0]); % Output low to port0/line1
        else
            write(dqDigital, [1, 1, 1]); % Output high to port0/line1
        end
    elseif occlusion_medium
            disp("medium occlusion")
        if percentage < mediumOcclusionThresh
            write(dqDigital, [1, 1, 0]); % Output low to port0/line1
        else
            write(dqDigital, [1, 1, 1]); % Output high to port0/line1
        end
    elseif occlusion_small
            disp("small occlusion")
        if percentage < smallOcclusionThresh
            write(dqDigital, [1, 1, 0]); % Output low to port0/line1
        else
            write(dqDigital, [1, 1, 1]); % Output high to port0/line1
        end
    elseif expansion
        disp("expansion")
        if percentage > expansionThresh
            write(dqDigital, [1, 0, 1]); % Output low to port0/line2
        else
            write(dqDigital, [1, 1, 1]); % Output high to port0/line2
        end
    else
        write(dqDigital, [1, 1, 1]); % Ensure relay is off when feedback control is not active
    end
end