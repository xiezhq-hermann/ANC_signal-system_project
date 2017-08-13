function latency = audioLatencyMeasurementExampleApp(bufferSize, ...
                                                plotFlag, useSimulink)
%AUDIOLATENCYMEASUREMENTEXAMPLEAPP Measure audio latency by using a
%loopback audio cable to connect the audio-out port to audio-in port.
%
% Input: bufferSize: The value of this parameter is used to set
% SamplesPerFrame property of audio file reader and audio device reader
% System objects or blocks. This input is optional, and the default value
% is 512.
% 
% plotFlag: Set this to true if you want to visualize the input to audio
% device writer and the output from audio device reader. This input is
% optional, and the default value is false.
% 
% useSimulink: Run the Simulink version of the example. This input is
% optional, and the default value is false.
%
% Output: 
% latency: The audio latency of the system in seconds.
%
% This function audioLatencyMeasurementExampleApp is only in support of
% AudioLatencyMeasurementExample. It may change in a future release.

% Copyright 2014-2016 The MathWorks, Inc.

%% Initialization
fprintf('Initializing... ');
if nargin < 1
    bufferSize = 512;
end
if nargin < 2
    plotFlag = false;
end

if nargin < 3
    useSimulink = true;
end

% Audio file to read from:
reader = dsp.AudioFileReader('guitar10min.ogg', ...
    'SamplesPerFrame',bufferSize);
Fs = 16000;
playDuration = 10;

if ~useSimulink
    % Measure latency using MATLAB System objects

    % Audio output
    player = audioDeviceWriter('SampleRate',Fs);

    % Audio input
    microphone = audioDeviceReader('SampleRate',Fs);
    microphone.SamplesPerFrame = bufferSize;

else
    % Measure latency using Simulink blocks
    
    modelName = 'audiolatencymeasurement';
    open_system(modelName);
    
    % Signal From Workspace block:
    set_param([modelName,'/Audio from file'], ...
        'Ts', ['1/',num2str(Fs)], ...
        'nsamps', num2str(bufferSize));

    % Audio Device Reader block:
    set_param([modelName,'/Audio Device Reader'], ...
        'SampleRate', num2str(Fs), ...
        'SamplesPerFrame', num2str(bufferSize));
end

% Signal sink to store played and recorded signals
NFrames = ceil(playDuration*Fs/bufferSize);
Buffer = zeros(NFrames*bufferSize,2);

% Store audio in local vector to not have disk access in the loop
reader.SamplesPerFrame = NFrames*bufferSize;
audioOut = reader();
if ~useSimulink
    % Call setup() on the audio device reader and writer objects.
    % This ensures that the audio queues and sound card are configured and
    % ready for data processing. This will minimize initial sample drops.
    setup(microphone);
    setup(player,audioOut(1:bufferSize,:));
end
fprintf('Done. \n');

%% Loopback simulation
fprintf('Streaming audio... ');
if ~useSimulink
    % MATLAB simulation
    for ind = 1:NFrames
        % Play through audio-out
        numUnderrun = play(player,audioOut((ind-1)*bufferSize+1:ind*bufferSize,:));
        
        % Record through audio-in
        [audioIn,numOverrun] = record(microphone);
        
        if ind > 10
            % Ignore first 10 frames as startup transient
            if numUnderrun > 0
                fprintf('\nAudio output queue was underrun by %d samples.', ...
                    numUnderrun);
            end
            if numOverrun > 0
                fprintf('\nAudio input queue was overrun by %d samples.', ...
                    numOverrun);
            end
            Buffer((ind-1)*bufferSize+1:ind*bufferSize,:) = ...
                [audioOut((ind-1)*bufferSize+1:ind*bufferSize, 1), audioIn(:,1)];
        end
    end
else
    % Simulink simulation
    set_param(modelName,'StopTime',num2str(playDuration));
    simout = sim(modelName,'SrcWorkspace','current');
    pause(0.1);
    numUnderrun = get(simout,'numUnderrun');
    numOverrun = get(simout,'numOverrun');
    audioIn = get(simout,'audioIn');
    if nnz(numUnderrun) > 0
        fprintf('\nAudio output queue was underrun during %d simulation steps.', ...
            nnz(numUnderrun));
    end
    if nnz(numOverrun) > 0
        fprintf('\nAudio input queue was overrun during %d simulation steps.', ...
            nnz(numOverrun));
    end
    % Ignore first 10 frames as startup transient
    Buffer = [audioOut(10*bufferSize+1:end,1),audioIn(10*bufferSize+1:end,1)];
end
fprintf('Done. \n');

%% Compute cross-correlation and plot
[temp,idx] = xcorr(Buffer(:,1),Buffer(:,2));
rxy = abs(temp);

[~,Midx] = max(rxy);
latency = -idx(Midx)*1/Fs;

if plotFlag
    fprintf('Plotting... ');
    
    figure
    t = 1/Fs*(0:size(Buffer,1)-1);
    plot(t,Buffer)
    title('Audio signals: Before audio player and after audio recorder');
    legend('Signal from audio file', ...
           'Signal recorded (added latency of audio input and output)');
    xlabel('Time (in sec)');
    ylabel('Audio signal');
    fprintf('Done. \n');
end

%% Cleanup
if ~useSimulink
    release(reader);      % release the input file
    release(player);      % release the audio output device
    release(microphone);  % release the audio input device
else
    %close_system(modelName,0);
end