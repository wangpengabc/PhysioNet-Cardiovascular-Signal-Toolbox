clear; clc; close all;

run(['..' filesep 'startup.m'])

baseFolder = 'I:\临时文件\BCG-ECG公开数据集\Dataset Files\Dataset Files\preprocessed';
remote_labelFolder = 'I:\临时文件\BCG-ECG公开数据集\Dataset Files\Dataset Files\label';
labelFolder = 'label';

if exist(baseFolder, 'dir') == 0
    fprintf('**** base Folder NOT EXIST !!!! **** \n');
end

% 1. Load Raw Patient Info and Signal name
infoFile = [baseFolder,filesep, 'datasetInfo.csv'];
info_table = readtable(infoFile);
info_table_size = size(info_table);
info_table_len = info_table_size(1);

sig_name_file = [baseFolder,filesep, 'signals_name.txt'];
fid = fopen(sig_name_file,'rt');
sig_name_list_cnt = 0;
sig_name_cell = {};
while true
    thisline = fgetl(fid);
    if ~ischar(thisline); break; end  %end of file
    sig_name_list_cnt = sig_name_list_cnt + 1;
    sig_name_cell{sig_name_list_cnt} = thisline;
end
fclose(fid);

for person_idx = 1:info_table_len

% 2. load data file 
% person_idx = 1;
person_id = info_table.ID{person_idx, 1}

    for sig_idx = 1:sig_name_list_cnt
%         sig_idx = 1;
        sig_name = sig_name_cell{1, sig_idx};

%         if strcmp(sig_name, 'ECG') || strcmp(sig_name, 'Film0') || strcmp(sig_name, 'Film1') || strcmp(sig_name, 'Film2') || strcmp(sig_name, 'Film3')
        if strcmp(sig_name, 'PPG') || strcmp(sig_name, 'ECG')
            sig_name
            suffix_type = {'_prep', '_raw'};
            for suffix_idx = 1:1
                suffix_name = suffix_type{suffix_idx};
                sig_name_file = [baseFolder,filesep, person_id,filesep, strcat(sig_name, suffix_name, 'data.csv')];
                sig_table = readtable(sig_name_file);
                sig_data = sig_table{:, sig_name};

                % 3. remove NaN data
                sig_data_rmNaN = rmmissing(sig_data);

                % 4. initialize HRVparams
                HRVparams = InitializeHRVparams('ECG_Slice'); % include the project name
                HRVparams.poincare.on = 0; % Poincare analysis off for this demo
                HRVparams.DFA.on = 0; % DFA analysis off for this demo
                HRVparams.MSE.on = 0; % MSE analysis off for this demo
                HRVparams.HRT.on = 0; % HRT analysis off for this demo
                HRVparams.af.on = 0; % Default: 1, AF Detection On or Off
                HRVparams.timedomain.on = 0; % Default: 1, Time Domain Analysis 1=On or 0=Off
                HRVparams.freq.on = 0; % Default: 1, Frequency Domain Analysis 1=On or 0=Off
                HRVparams.sd.on = 0; % Default: 1, SD analysis 1=On or 0=Off
                HRVparams.prsa.on = 0; % Default: 1, PRSA Analysis 1=On or 0=Off
                HRVparams.writedata = strcat(labelFolder, filesep, person_id); 

                % 4. calculate SQI
                switch sig_name 
                    case 'ECG'
                        [t, rr, jqrs_ann, SQIvalue , tSQI] = ConvertRawDataToRRIntervals(sig_data, HRVparams, sig_name);
                        remote_labelFolder_person = [remote_labelFolder,filesep, person_id];
                        if ~exist(remote_labelFolder_person, 'dir')
                            mkdir(remote_labelFolder_person)
                        end
                        csvwrite([remote_labelFolder,filesep, person_id,filesep, strcat(sig_name, suffix_name, '_ann.csv')], jqrs_ann.');
                        csvwrite([remote_labelFolder,filesep, person_id,filesep, strcat(sig_name, suffix_name, '_SQI.csv')], SQIvalue.');

%                         time = 1:1:size(sig_data);
%                         time = time / HRVparams.Fs;
%                         HRVparams.gen_figs = 1;
%                         % Plot detected beats
%                         if HRVparams.gen_figs
%                             Plot_SignalDetection_SQI(time, sig_data, jqrs_ann, SQIvalue,'ECG')
%                         end
        
                    case 'PPG'
                        [rr,t,sqi] = Analyze_ABP_PPG_Waveforms(sig_data, {'PPG'}, HRVparams, [], person_id);
                        [PPGann] = qppg(sig_data, HRVparams.Fs);
                        
%                         [t, rr, jqrs_ann, SQIvalue , tSQI] = ConvertRawDataToRRIntervals(sig_data, HRVparams, sig_name);
                        remote_labelFolder_person = [remote_labelFolder,filesep, person_id];
                        if ~exist(remote_labelFolder_person, 'dir')
                            mkdir(remote_labelFolder_person)
                        end
                        csvwrite([remote_labelFolder,filesep, person_id,filesep, strcat(sig_name, suffix_name, '_ann.csv')], PPGann.');
%                         csvwrite([remote_labelFolder,filesep, person_id,filesep, strcat(sig_name, suffix_name, '_ppgSQI.csv')], sqi(:, 2));
                        csvwrite([remote_labelFolder,filesep, person_id,filesep, strcat(sig_name, suffix_name, '_SQI.csv')], sqi);
                        
%                         time = 1:1:size(sig_data);
%                         time = time / HRVparams.Fs;
%                         HRVparams.gen_figs = 1;
%                         % Plot detected beats
%                         if HRVparams.gen_figs
%                             Plot_SignalDetection_SQI(time, sig_data, PPGann, sqi(:, 2), 'PPG')
%                         end
                end
                
            end
        end

    end % sig_idx

end % person_idx 










