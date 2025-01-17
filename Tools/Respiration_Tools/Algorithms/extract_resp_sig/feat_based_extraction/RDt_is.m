function [ekg_RDtGC_EHF] = RDt_is(ekg_EHF, up)
% Peak detector

rel_name = 'ekg_EHF';
eval(['s = ' rel_name ';']);
eval(['fs = ' rel_name '.fs;']);
s.v = s.v(:);

%% Eliminate very low frequencies
s_filt = elim_sub_cardiac(s, up);
nan_els = isnan(s_filt.v);
s_filt.t = s_filt.t(~nan_els);
s_filt.v = s_filt.v(~nan_els);

%% Detect QRS Waves
subj = 1;
pk_inds = feval('GC', s_filt, fs, subj, up);

%% Refine detected QRS spikes
% The detected peaks are currently somewhere in the middle of the R-area, so need to search for the max ecg value within the tolerance either side of the detected peak:
max_HR_for_qrs = 300;
tolerance = round(fs/(max_HR_for_qrs/60));
if ~isempty(pk_inds)
    % refine the peaks and store in a new variable (ECG_PKS_inds)
    ref_pk_inds = nan(length(pk_inds),1);
    for peak_ind = 1 : length(pk_inds)                             % for each peak
        % Find tolerance limits, centred on the current peak index:
        if pk_inds(peak_ind) <= tolerance                          % if the peak is right at the start of the recording, set the lower tolerance limit to the start of the recording
            lower_lim = 1;
        else
            lower_lim = pk_inds(peak_ind)-tolerance;
        end
        if (length(s.v)-pk_inds(peak_ind)) <= tolerance % if the peak is right at the end of the recording, set the upper tolerance limit to the end of the recording
            upper_lim = length(s.v);
        else
            upper_lim = pk_inds(peak_ind)+tolerance;
        end
        % Find the maximum ecg value within the tolerance limits:
        [~, max_ind] = max(s.v(lower_lim : upper_lim));
        % Store the index of this maximum value, referenced to the section_data inds:
        ref_pk_inds(peak_ind) = lower_lim-1+max_ind;
        clear max_ind
    end
    clear peak_ind
else
    % if no peaks were detected then give empty results:
    ref_pk_inds = [];
end

%% Eliminate any peaks which are the same
ref_pk_inds = unique(ref_pk_inds);

%% Find troughs
% search 0.1s either side
troughs.i = nan(length(ref_pk_inds)-1,1);
search_min = ref_pk_inds - ceil(0.1*fs);
search_min(search_min<1) = 1;
search_max = ref_pk_inds + ceil(0.1*fs);
search_max(search_max>length(s.v)) = 1;
for peak_ind = 1 : (length(ref_pk_inds)-1)
    [~, rel_el] = min(s.v(search_min(peak_ind):search_max(peak_ind)));
    rel_el = search_min(peak_ind)-1+rel_el;
    troughs.i(peak_ind) = rel_el;
end

% save_name = 'ekg_RDtGC_EHF';
% %% Save processed data
% eval([save_name '.fs = fs;']);
% eval([save_name '.p.v = s.v(ref_pk_inds);']);
% eval([save_name '.p.t = s.t(ref_pk_inds);']);
% eval([save_name '.tr.v = s.v(troughs.i);']);
% eval([save_name '.tr.t = s.t(troughs.i);']);
% % Identify start and end times of raw data (for resampling)
% eval([save_name '.timings.t_start = s.t(1);']);
% eval([save_name '.timings.t_end = s.t(end);']);
ekg_RDtGC_EHF.fs = fs;
ekg_RDtGC_EHF.p.v = s.v(ref_pk_inds);
ekg_RDtGC_EHF.p.t = s.t(ref_pk_inds);
ekg_RDtGC_EHF.tr.v = s.v(troughs.i);
ekg_RDtGC_EHF.tr.t = s.t(troughs.i);
ekg_RDtGC_EHF.timings.t_start = s.t(1);
ekg_RDtGC_EHF.timings.t_end = s.t(end);

end

function pk_inds = GC(s, fs, subj, up)

%% This uses Prof Gari Clifford's "rpeakdetect.m" script
% This script can be downloaded from:
%    http://www.mit.edu/~gari/CODE/ECGtools/ecgBag/rpeakdetect.m
%
% The following is an excerpt from the script:
%
% Written by G. Clifford gari@ieee.org and made available under the
% GNU general public license. If you have not received a copy of this
% license, please download a copy from http://www.gnu.org/
%
% Please distribute (and modify) freely, commenting
% where you have added modifications.
% The author would appreciate correspondence regarding
% corrections, modifications, improvements etc.

% download the script if it isn't in the search path
curr_dir = mfilename('fullpath'); curr_dir = curr_dir(1:end-6);
filepath = [curr_dir, 'rpeakdetect.m'];
if ~exist(filepath, 'file')
    url = 'http://www.mit.edu/~gari/CODE/ECGtools/ecgBag/rpeakdetect.m';
    downloadedfilename = websave(filepath,url);
end

[~, ~, ~, pk_inds, ~, ~]  = rpeakdetect(s.v(:),fs);

end
