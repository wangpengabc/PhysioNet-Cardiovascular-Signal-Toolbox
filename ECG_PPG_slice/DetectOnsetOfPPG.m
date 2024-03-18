baseFolder = 'F:\�����ź����ݼ�\mimic-iii\��֢ɸѡ���\data';
labelFolder = 'F:\�����ź����ݼ�\mimic-iii\��֢ɸѡ���\label';
local_labelFolder = 'label';
subFolder = 'mimic3wdb-matched\p02';

disease_name_struct = dir(baseFolder);
disease_name_struct_size = size(disease_name_struct);
disease_name_struct_len = disease_name_struct_size(1);

for i=3:disease_name_struct_len % ʡȥ��ͷ��. .. �����ļ���
    disease_name = disease_name_struct(i).name;
    fprintf(disease_name);
    fprintf("\n");
    % ֻ����42789_p03�ļ����µ�����
    if strcmp(disease_name, "42789������_arrhy") == 0
        continue
    end

    
    fprintf(disease_name);
    fprintf("\n");

    fprintf(strcat('************************************',disease_name,'************************************\n'));
    disease_base_path = [baseFolder,filesep, disease_name, filesep, subFolder];
    disease_label_base_path = [labelFolder,filesep, disease_name, filesep, subFolder];
    
    subject_id_path_struct = dir(disease_base_path);
    subject_id_path_struct_size = size(subject_id_path_struct);
    subject_id_path_struct_len = subject_id_path_struct_size(1);
    
    
    for subj_idx=3:subject_id_path_struct_len
        subject_id = subject_id_path_struct(subj_idx).name;
        fprintf(strcat('******************',subject_id,'******************\n'));
        subject_id_path = [disease_base_path,filesep, subject_id];
        label_subject_id_path = [disease_label_base_path,filesep, subject_id];
        
        subject_data_path_struct = dir(subject_id_path);
        subject_data_path_struct_size = size(subject_data_path_struct);
        subject_data_path_struct_len = subject_data_path_struct_size(1);
        
         % initialize HRVparams
        HRVparams = InitializeHRVparams('ECG_PPG_Anno_MIMIC'); % include the project name
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
        
        % random choose 4 if subject_data_path_struct_len if greater than
        % 4, else just choose subject_data_path_struct_len
        if (subject_data_path_struct_len-2) > 4
            subj_data_idx_list = randsample(subject_data_path_struct_len-2, 4);
        else
            subj_data_idx_list = 1:1:(subject_data_path_struct_len-2);
        end
        
        for random_list_idx=1:length(subj_data_idx_list)
            subj_data_idx = subj_data_idx_list(random_list_idx) + 2;
            subject_data_filename = subject_data_path_struct(subj_data_idx).name;
            fprintf(strcat('******',subject_data_filename,'******\n'));
            subject_data_path = [subject_id_path,filesep, subject_data_filename];
            
            subject_data = readtable(subject_data_path);
            ecg_data = subject_data.II;
            ppg_data = subject_data.PLETH;
            
            if ~exist(label_subject_id_path, 'dir')
                mkdir(label_subject_id_path)
            end
            
            try
                
                % ecg 
                ECGann_filepath = [label_subject_id_path,filesep, strcat('ECGann_', subject_data_filename)];
                ECGsqi_filepath = [label_subject_id_path,filesep, strcat('ECGsqi_', subject_data_filename)];
                if ~(isfile(ECGann_filepath) && isfile(ECGsqi_filepath))
                    [t, rr, jqrs_ann, SQIvalue , tSQI] = ConvertRawDataToRRIntervals(ecg_data, HRVparams, subject_id);
                    csvwrite(ECGann_filepath, jqrs_ann.');
                    csvwrite(ECGsqi_filepath, SQIvalue.');
                end

                % PPG 
                PPGann_filepath = [label_subject_id_path,filesep, strcat('PPGann_', subject_data_filename)];
                PPGsqi_filepath = [label_subject_id_path,filesep, strcat('PPGsqi_', subject_data_filename)];
                if ~(isfile(PPGann_filepath) && isfile(PPGsqi_filepath))
                    [rr,t,sqi] = Analyze_ABP_PPG_Waveforms(ppg_data, {'PPG'}, HRVparams, [], subject_id);
                    [PPGann] = qppg(ppg_data, HRVparams.Fs);
                    csvwrite(PPGann_filepath, PPGann.');
                    csvwrite(PPGsqi_filepath, sqi);
                end
            catch
                fprintf('ERROR\n');
                continue
            end
            
        end
        
    end
end

fprintf('FINISHED!!!');