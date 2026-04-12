%% load motion corrected h5 file and format for EXTRACT

%% variables passed from command line
%filePath = '/Users/johnmarshall/Documents/Analysis/miniscope_analysis/gray_00denoised00_converted___motion_corrected.h5';
%num_partitions
%savePath = '/Users/johnmarshall/Documents/Analysis/nVueData/SPRT/';

% ---- INPUT: filePath can be .h5 or .mat ----
[dirPath, session, ext] = fileparts(filePath);

dsetName = '/mov';     % for .h5
matVar   = 'Y';        % for .mat (change if needed)

switch lower(ext)
    case {'.h5', '.hdf5'}
        % Stream from disk (recommended for big movies)
        M = {filePath, dsetName};

        info = h5info(filePath, dsetName);
        % If stored as single: 4 bytes; uint16: 2 bytes, etc.
        bytesPerEl = double(info.Datatype.Size);
        movieInGB = prod(double(info.Dataspace.Size)) * bytesPerEl / 1024^3;

    case '.mat'
        % Load into RAM (can be huge!)
        M = {filePath, matVar};
        mf = matfile(filePath);
        sz = size(mf, matVar);
        movieInGB = prod(double(sz)) * 2 / 1024^3;

    otherwise
        error('Unsupported input "%s". Use .h5/.hdf5 (dataset %s) or .mat (variable %s).', ...
              ext, dsetName, matVar);
end

fprintf('Movie size estimate: %.3f GB\n', movieInGB);
disp('path to save output file:');
disp(savePath);

disp('path to save output file:');
disp(savePath);
%% set parameters for extraction

%display GPU engagement if available
try
	d = gpuDevice;
	disp(d.Name);
	disp(d.Index);
	disp(d.AvailableMemory/2^30);
catch
	disp("No GPU available (CPU run.)");
end

config=[];
config = get_defaults(config); 
config.avg_cell_radius=avg_cell_radius;
config.trace_output_option=trace_output_option;
config.num_partitions_x=num_partitions;
config.num_partitions_y=num_partitions; 
config.use_gpu=0; 
config.multi_gpu=0;
config.parallel_cpu=1;
% Use CPUs allocated by Slurm (leave 1 core for overhead by default)
n = str2double(getenv("SLURM_CPUS_PER_TASK"));
if isnan(n) || n < 1
    % fallback if running outside Slurm
    n = feature("numcores");
end

config.num_workers = max(1, n - 1);   % or use n if you want to use all cores
fprintf("SLURM_CPUS_PER_TASK=%d -> config.num_workers=%d\n", n, config.num_workers);

config.max_iter = 10; 
config.cellfind_min_snr=cellfind_min_snr;
config.thresholds.T_min_snr=T_min_snr;
config.use_sparse_arrays=0;
config.dendrite_aware=logical(dendrite_aware);

fprintf("avg_cell_radius=%g\n", config.avg_cell_radius);
fprintf("trace_output_option=%s\n", string(config.trace_output_option));
fprintf("cellfind_min_snr=%g\n", config.cellfind_min_snr);
fprintf("T_min_snr=%g\n", config.thresholds.T_min_snr);
fprintf("dendrite_aware=%d\n", config.dendrite_aware);

%%
%%run EXTRACT
p = gcp('nocreate');
if isempty(p) || p.NumWorkers ~= config.num_workers
     if ~isempty(p), delete(p); end	     
     parpool('local', config.num_workers);
end

output=extractor_MATcompatible(M,config);

%%
ts = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));

if ~exist(savePath, "dir")
     mkdir(savePath);
end

savePathMATLAB = fullfile(savePath, sprintf('%s_%s.mat', session, ts));
fprintf("Saving to: %s\n", savePathMATLAB);
save(savePathMATLAB, 'output', '-v7.3');

%savePathh5 = strcat(savePath, session, '.h5');
%fields = fieldnames(output); % Get the field names of the structure
%for i = 1:numel(fields)
%    % Get the data and field name
%    fieldName = fields{i};
%    data = output.(fieldName);
%    % Create dataset in the HDF5 file
%    h5create(savePathh5, ['/', fieldName], size(data), 'Datatype', class(data));    
%    % Write data to the dataset
%    h5write(savePathh5, ['/', fieldName], data);
%end
