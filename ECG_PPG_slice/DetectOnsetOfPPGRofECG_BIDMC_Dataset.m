clear;

% baseFolder = 'F:\生理信号数据集\mimic-iii\病症筛选结果\data';
% labelFolder = 'F:\生理信号数据集\mimic-iii\病症筛选结果\label';
baseFolder = 'F:\生理信号数据集\bidmc-ppg-and-respiration-dataset-1.0.0\bidmc_csv';
labelFolder = 'F:\生理信号数据集\bidmc-ppg-and-respiration-dataset-1.0.0\bidmc_csv_label';
local_labelFolder = 'label_BIDMC';
subject_num = 53;

for subject_idx=1:subject_num 
%     % 只处理42789_p03文件夹下的数据
%     if strcmp(disease_name, "42789所有人_arrhy") == 0
%         continue
%     end
    if subject_idx < 10
        subject_idx_str = strcat("0", int2str(subject_idx));
    else
        subject_idx_str = int2str(subject_idx);
    end
    subject_data_filename = strcat("bidmc_", subject_idx_str, "_Signals.csv");
    fprintf(strcat('************************************ subject_data_filename:  ', subject_data_filename, '************************************\n'));
    subject_id = int2str(subject_idx);

    % initialize HRVparams
%     F:\生理信号数据集\mimic-iii\病症筛选结果\tools\PhysioNet-Cardiovascular-Signal-Toolbox\InitializeHRVparams.m 在增加新的数据集时，需要在该文件增加数据集的一些参数
    HRVparams = InitializeHRVparams('ECG_PPG_Anno_BIDMC'); % include the project name
    HRVparams.poincare.on = 0; % Poincare analysis off for this demo
    HRVparams.DFA.on = 0; % DFA analysis off for this demo
    HRVparams.MSE.on = 0; % MSE analysis off for this demo
    HRVparams.HRT.on = 0; % HRT analysis off for this demo
    HRVparams.af.on = 0; % Default: 1, AF Detection On or Off
    HRVparams.timedomain.on = 0; % Default: 1, Time Domain Analysis 1=On or 0=Off
    HRVparams.freq.on = 0; % Default: 1, Frequency Domain Analysis 1=On or 0=Off
    HRVparams.sd.on = 0; % Default: 1, SD analysis 1=On or 0=Off
    HRVparams.prsa.on = 0; % Default: 1, PRSA Analysis 1=On or 0=Off
    HRVparams.writedata = strcat(local_labelFolder, filesep, subject_id); 

    subject_data_path = strcat(baseFolder, filesep, subject_data_filename);

    subject_data = readtable(subject_data_path);
    ecg_data = subject_data.II;
    ppg_data = subject_data.PLETH;

    if ~exist(labelFolder, 'dir')
        mkdir(labelFolder)
    end

%     try
        % ecg 
        ECGann_filepath = strcat(labelFolder,filesep, strcat('ECGann_', subject_data_filename));
        ECGsqi_filepath = strcat(labelFolder,filesep, strcat('ECGsqi_', subject_data_filename));
        if ~(isfile(ECGann_filepath) && isfile(ECGsqi_filepath))
            [t, rr, jqrs_ann, SQIvalue , tSQI] = ConvertRawDataToRRIntervals(ecg_data, HRVparams, subject_id);
            csvwrite(ECGann_filepath, jqrs_ann.');
            csvwrite(ECGsqi_filepath, SQIvalue.');
        end

        % PPG 
        PPGann_filepath = strcat(labelFolder,filesep, strcat('PPGann_', subject_data_filename));
        PPGsqi_filepath = strcat(labelFolder,filesep, strcat('PPGsqi_', subject_data_filename));
        if ~(isfile(PPGann_filepath) && isfile(PPGsqi_filepath))
            [rr,t,sqi] = Analyze_ABP_PPG_Waveforms(ppg_data, {'PPG'}, HRVparams, [], subject_id);
            [PPGann] = qppg(ppg_data, HRVparams.Fs);
            csvwrite(PPGann_filepath, PPGann.');
            csvwrite(PPGsqi_filepath, sqi);
        end
%     catch
%         fprintf('ERROR\n');
%         continue
%     end
end

fprintf('FINISHED!!!');
