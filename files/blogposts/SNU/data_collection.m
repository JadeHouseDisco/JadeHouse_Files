clear
clc
close all

%% parameter setting
end_time = 10; %1281
repeat = 2;
per_time = end_time/repeat;

Vout = 10;

%% file data init
testNum = 1;
% file_name = ['Device_flex_sensor_test_',num2str(testNum),'_',datestr(now,'mm-dd_HHMM')];
file_name = 'Device_flex_sensor_100';
Saving = 1;

%% file saving
rawFileOut = fopen([file_name '.txt'],'w');
fprintf(rawFileOut,'time, voltageIn\n');

%%
% DAQ start

d = daqlist;
d(1,:)

d{1, "DeviceInfo"}
dq = daq("ni");
dq.Rate = 2000;
addoutput(dq, "myDAQ1", "ao0", "Voltage");
ai0 = addinput(dq, "myDAQ1", "ai0", "Voltage");
ai0.TerminalConfig = 'Differential';

% Setup digital outputs separately
dqDigital = daq("ni");
addoutput(dqDigital, "myDAQ1", 'port0/line0', "Digital");
addoutput(dqDigital, "myDAQ1", 'port0/line1', "Digital");
addoutput(dqDigital, "myDAQ1", 'port0/line2', "Digital");

dq.ScansAvailableFcn = @(src, evt) plotMyData(src, evt, rawFileOut);
dq.ScansAvailableFcnCount = dq.Rate / 10;

%%
out = Vout * ones(1,dq.Rate*end_time); % Set constant output voltage

%% voltage init
preload(dq,out')
start(dq,"repeatoutput")

%% plot init

% subplot(2,1,1)
% ax1 = gca;
% ax1.YLim=[0 3]; % adjust limit for visibility of 10V
% title("Input Voltage")
% xlabel("sec")
% ylabel("V")

tic;
elapsed_time = toc;
relay_start_time = tic; % start time for relay control

while elapsed_time < end_time
    elapsed_time = toc;
    pause(0.01)
    
    % Relay control logic
    relay_elapsed_time = toc(relay_start_time);
    if relay_elapsed_time < 180 % IN1: HIGH, IN2: HIGH for 3 minutes
        write(dqDigital, [1, 1, 1]);
    elseif relay_elapsed_time < 186 % IN1: LOW, IN2: HIGH for 5 seconds
        write(dqDigital, [1, 0, 1]);
    elseif relay_elapsed_time < 366 % IN1: HIGH, IN2: HIGH for 3 minutes
        write(dqDigital, [1, 1, 1]);
    elseif relay_elapsed_time < 372 % IN1: HIGH, IN2: LOW for 2 seconds
        write(dqDigital, [1, 1, 0]);
    else % Reset the relay control cycle
        relay_start_time = tic;
    end

    % ax1.XLim = [elapsed_time - 5, elapsed_time + 5];
    % ax1.YLim = [0 3]; % adjust limit for visibility of 10V
end

%% finished
stop(dq)

flush(dq)
write(dq,0)

daqreset
fclose(rawFileOut);

%% data save
if Saving
    filename = [file_name '.txt'];
else
    temp_name=strcat([file_name '.txt']);
    delete('%s',temp_name);
end

disp("Finished")

%% Function declaration
function plotMyData(src,~,rawFileOut)
    [data, timestamps] = read(src, src.ScansAvailableFcnCount, "OutputFormat", "Matrix");
        
    input_voltage = data(:,1);
    fprintf(rawFileOut, '%.4f, %.4f\n', [timestamps, input_voltage].');
    
    % subplot(2,1,1)
    % hold on
    % grid on
    % plot(timestamps, input_voltage,'r');

end

%% Plot data
% Read the data from the text file

% file_name = 'Device_flex_sensor_test_1_08-07_1903'

fileID = fopen([file_name '.txt'], 'r');
data = textscan(fileID, '%f %f', 'HeaderLines', 1, 'Delimiter', ',');
fclose(fileID);

% Extract the time and voltage columns
time = data{1};
voltageIn = data{2};

% Calculate and display the average voltage
averageVoltage = mean(voltageIn);
disp(['Average Voltage: ', num2str(averageVoltage), ' V']);

% Calculate the moving average
windowSize = 10000;
voltageInMovingAvg = movmean(voltageIn, windowSize);

% Plot the data and moving average
figure;
plot(time, voltageIn, 'b', 'DisplayName', 'Voltage In');
hold on;
plot(time, voltageInMovingAvg, 'r', 'DisplayName', 'Moving Average');
title('Time vs Voltage with Moving Average');
xlabel('Time (s)');
ylabel('Voltage (V)');
legend;
% Add text to the plot displaying the average voltage
% text(max(time)*0.7, max(voltageIn)*0.9, ['Avg Voltage: ', num2str(averageVoltage), ' V'], 'Color', 'k', 'FontSize', 12);
grid on;