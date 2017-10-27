function [ulf, vlf, lf, hf, lfhf, ttlpwr, fdflag] = EvalFrequencyDomainHRVstats(NN, tNN, sqi, HRVparams, windows_all)
%
% [ulfL, vlfL, lfL, hfL, lfhfL, ttlpwrL, fdflag, windows_all] = ...
%         EvalFrequencyDomainHRVstats (NN, tNN, , sqi, settings)
%   
%   OVERVIEW:   This function returns frequency domain HRV metrics 
%               calculated on input NN intervals.
%
%   INPUT:      MANDATORY:
%               NN          : a single row of NN (normal normal) interval
%                             data in seconds
%               
%               OPTIONAL:
%               tNN         : a single row of time indices of the rr interval 
%                             data (seconds)
%               sqi         : Signal Quality Index; Requires a matrix with
%                             at least two columns. Column 1 should be
%                             timestamps of each sqi measure, and Column 2
%                             should be SQI on a scale from 0 to 1.
%                             Additional columns can be included with
%                             additional sqi at the same timestamps
%               HRVparams   : struct of settings for hrv_toolbox analysis
%
%   OUTPUT:     ulf        :
%               vlf        :
%               lf         :
%               hf         :
%               lfhf       :
%               ttlpwr     :
%               fdflag     : 1 - Lomb Periodogram or other method failed
%                            2 - Not enough high SQI data
%                            3 - Not enough data in the window to analyze
%                            4 - Window is missing too much data
%                            5 - Success
%
%   DEPENDENCIES & LIBRARIES:
%       HRV_toolbox https://github.com/cliffordlab/hrv_toolbox
%       WFDB Matlab toolbox https://github.com/ikarosilva/wfdb-app-toolbox
%       WFDB Toolbox https://physionet.org/physiotools/wfdb.shtml
%   REFERENCE: 
%	REPO:       
%       https://github.com/cliffordlab/hrv_toolbox
%   ORIGINAL SOURCE AND AUTHORS:     
%       Gari Clifford HRV Tools
%                   G. Clifford 2001 gari@mit.edu, calc_lfhf.m 
%                   http://www.robots.ox.ac.uk/~gari/CODE/HRV/
%       ChengYu Lui
%       Adriana Vest
%       Dependent scripts written by various authors 
%       (see functions for details)       
%	COPYRIGHT (C) 2016 
%   LICENSE:    
%       This software is offered freely and without warranty under 
%       the GNU (v3 or later) public license. See license file for
%       more information  
%%

% Verify input arguments

if nargin< 1
    error('Eval_FrequencydomainHRVstats: wrong number of input arguments!')
end
if nargin<2 || isempty(tNN)
        tNN = cumsum(NN);
end
if nargin<3 || isempty(sqi) 
        sqi(:,1) = tNN;
        sqi(:,2) = ones(length(tNN),1);
end
if nargin<4 || isempty(HRVparams) 
        HRVparams = initialize_HRVparams('demo');
end
if nargin<5 || isempty(windows_all)
    windows_all = CreateWindowRRintervals(tNN, NN, HRVparams);
end

% Set Defaults


windowlength = HRVparams.windowlength;
fd_threshold1 = HRVparams.freq.threshold1;
fd_threshold2 = HRVparams.freq.threshold2;
limits = HRVparams.freq.limits;
method = HRVparams.freq.methods{1};
plot_on = HRVparams.freq.plot_on;
debug_sine = HRVparams.freq.debug_sine;   % if use the sine wave to debug
f_sine = HRVparams.freq.debug_freq;       % the frequency of the added sine wave
weight = HRVparams.freq.debug_weight;



% Preallocate arrays before entering the loop

ulf = nan(1,length(windows_all));
vlf = nan(1,length(windows_all));
lf = nan(1,length(windows_all));
hf = nan(1,length(windows_all));
lfhf = nan(1,length(windows_all));
ttlpwr = nan(1,length(windows_all));
fdflag = nan(1,length(windows_all));

%% Window by Window Analysis

% Loop through each window of RR data
for iWin = 1:length(windows_all)
    % Check window for sufficient data
    if ~isnan(windows_all(iWin))    
        % Isolate data in this window
        idx_NN_in_win = find(tNN >= windows_all(iWin) & tNN < windows_all(iWin) + windowlength);
        idx_sqi_win = find(sqi(:,1) >= windows_all(iWin) & sqi(:,1) < windows_all(iWin) + windowlength);

        sqi_win = sqi(idx_sqi_win,:);
        t_win = tNN(idx_NN_in_win);
        nn_win = NN(idx_NN_in_win);

        % Analysis of SQI for the window
        lowqual_idx = find(sqi_win(:,2) < fd_threshold1);

        % If enough data has an adequate SQI, perform the calculations
        if numel(lowqual_idx)/length(sqi_win(:,2)) < fd_threshold2

            % Initialize variables
            % maxF=fs/2; % This calculation works for regularly sampled data
            N     =  length(nn_win);       % RR interval series length
            % m_fs  = 1/mean(nn_win);     % mean frequency of heart rate, i.e., the mean sample rate (fs) of RR sereis  
            % max_f = .5/(min(nn_win));   % max frequency of RR interval series
            % nfft  = 2^nextpow2(N);      % Next power of 2 from N
            nfft = 1024;
            %F = [1/nfft:1/nfft:m_fs];  % setting up frequency vector
            F = [1/nfft:1/nfft:.5];  % setting up frequency vector

            % add sine wave to RR signal
            if debug_sine
                s_sin  = weight*sin(2*pi*f_sine*t);
                nn_win = nn_win + s_sin;
            end

            % subtract mean of segment
            if HRVparams.freq.zero_mean
                rr_0 = nn_win - mean(nn_win); %rudimentary detrending
            else
                rr_0 = nn_win;
            end
            % 1. Lomb-Scargle Periodogram (before resampling)
            switch method
                case 'lomb'
                    try
                        [PSDlomb,Flomb] = CalcLomb(t_win,rr_0,F,nfft,HRVparams.freq.normalize_lomb);
                        % plomb equivalent to CalcLomb when normalized 
                        % lomb-scargle periodogram
                        %[PSDmatlablomb,fplombout] = plomb(vv,tt,F,'normalized');
                        [ulf(iWin), vlf(iWin), lf(iWin), hf(iWin), lfhf(iWin),...
                            ttlpwr(iWin)] = CalcLfHfParams(PSDlomb, Flomb, limits, plot_on);
                        
                        fdflag(iWin) = 5; %'sucess';

                    catch
                        fdflag(iWin) = 1; %'lomb_failed'
                    end
                    

            % 2. Burg Method (before resampling)
                case 'burg'
                    try
                        p = HRVparams.freq.burg_poles; % pole setting
                        [PSDburgBRS,FburgBRS] = pburg(rr_0,p,F,m_fs);
                        [ulf(iWin), vlf(iWin), lf(iWin), hf(iWin), lfhf(iWin),...
                                ttlpwr(iWin)] = CalcLfHfParams(PSDburgBRS, FburgBRS, limits, plot_on);
                        fdflag(iWin) = 5; %'sucess';
                    catch
                        fdflag(iWin) = 1; %'burg faild';
                    end

           
            % 3. FFT (before resampling)
                case 'fft'
                    try
                        %Y = fft(rr_0); 
                        %P2 = abs(Y); % The two sided spectrum
                        %P1 = P2(1:N/2+1); % Single sided spectrum
                        %P1(2:end-1) = 2*P1(2:end-1);
                        %f = 7*(0:(N/2))/N;
                        Y_FFT0       = fft(rr_0);  % fft using the original sample length
                        PSD_FFT0     = Y_FFT0.*conj(Y_FFT0)/N; % double sided spectrum
                        %m_fs0 = 1/mean(rr_0);
                        f_FFT0       = m_fs*(0:N/2+1)/N; 
                        % temporary!
                        f_FFT0      = 7*(0:(N/2))/N;
                         [ulf(iWin), vlf(iWin), lf(iWin), hf(iWin), lfhf(iWin),...
                                ttlpwr(iWin)] =  CalcLfHfParams(PSD_FFT0(1:length(f_FFT0)), f_FFT0, limits, plot_on);
                        fdflag(iWin) = 5; %'sucess';
                    catch
                        fdflag(iWin) = 1; %'fft faild';
                    end
   
               
            % 4. Pwelch (before resampling)
                case 'welch'
                    try
                        % temporary!
                        m_fs  = 7;
                        [PSDwelchBRS,FwelchBRS] = pwelch(rr_0,[],[],2^nextpow2(length(rr_0)),m_fs);
                        [ulf(iWin), vlf(iWin), lf(iWin), hf(iWin), lfhf(iWin),...
                                ttlpwr(iWin)] =  CalcLfHfParams(PSDwelchBRS, FwelchBRS, limits, plot_on);
                        fdflag(iWin) = 5; %'sucess';
                    catch
                        fdflag(iWin) = 1; %'Pwelch faild';
                    end
                    
            end       
                    
            % Do resampling before to apply methods that require resampled
            % data
            sf = HRVparams.freq.resampling_freq; % (Hz) resampling frequency
            ti = t_win(1):1/sf:t_win(end);       % time values for interp.
            interp_method = HRVparams.freq.resample_interp_method;
            
            % Chose the resampling method to use
            switch interp_method 
                case 'cub'
                    rr_int = interp1(t_win,rr_0,ti','spline')'; % cubic spline interpolation
                case 'lin'
                    rr_int = interp1(t_win,rr_0,ti','linear')'; %linear interpolation
                otherwise
                    warning('using cubic spline method')
                    rr_int = interp1(t_win,rr_0,ti','spline')'; % cubic spline interpolation
            end
            
            switch method   
                % 5. Pwelch (after resampling)
                case 'welch_rs'
                    try
                        [PSDwelch,Fwelch] = pwelch(rr_int,[],[],2^nextpow2(length(rr_int)),sf);
                        [ulf(iWin), vlf(iWin), lf(iWin), hf(iWin), lfhf(iWin),...
                                ttlpwr(iWin)] = CalcLfHfParams(PSDwelch, Fwelch, limits, plot_on) ;  
                        fdflag(iWin) = 5; %'sucess';
                    catch
                        fdflag(iWin) = 1; %'Pwelch faild';
                    end
                    
                % 6. FFT (after resampling)
                case 'fft_rs'
                    try
                        Y_FFT2 = fft(rr_int);  % fft using the original sample length
                        PSDfft = Y_FFT2.*conj(Y_FFT2)/length(rr_int);
                        Ffft = sf*(0:floor(length(rr_int)/2)+1)/length(rr_int);
                        [ulf(iWin), vlf(iWin), lf(iWin), hf(iWin), lfhf(iWin),...
                                ttlpwr(iWin)] = CalcLfHfParams(PSDfft(1:length(Ffft)), Ffft, limits, plot_on);
                        fdflag(iWin) = 5; %'sucess';
                    catch
                        fdflag(iWin) = 1; %'fft faild';
                    end

                % 7. Burg (after resampling)
                case 'burg_rs'
                    try
                    % ChengYu's Burg Method with resampled data
                    pb = HRVparams.freq.resampled_burg_poles; % pole setting
                    [PSD_Burg1,f_Burg1] = pburg(rr_int,pb,2^nextpow2(length(rr_int)),sf);
                    [ulf(iWin), vlf(iWin), lf(iWin), hf(iWin), lfhf(iWin),...
                            ttlpwr(iWin)] = CalcLfHfParams(PSD_Burg1,f_Burg1, limits, plot_on);
                        fdflag(iWin) = 5; %'sucess';
                    catch
                        fdflag(iWin) = 1; %'Burg faild';
                    end
            end
        else
            fdflag(iWin) = 2; %'nt_enuf_hi_sqi_data'
        end % end conditional statements that run only if SQI is adequate

    else
        fdflag(iWin) = 3; %'nt_enuf_data_in_win';
        
    end % end check for sufficient data

end % end of loop through windows
end % end function


%   References:
%               5 minutes is the shortest period that HRV spectral metrics
%               should be calculated according to 184(Clifford Thesis). With a 5 min
%               window, the lowest frequency that can be theoretically resolved is
%               1/300 (.003 Hz).