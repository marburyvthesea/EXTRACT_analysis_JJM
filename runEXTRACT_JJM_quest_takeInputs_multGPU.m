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
        bytesPerEl = datatype_bytes(info.Datatype);
        movieInGB = prod(double(info.Dataspace.Size)) * bytesPerEl / 1024^3;

    case '.mat'
        % Load into RAM (can be huge!)
        S = load(filePath, matVar);
        if ~isfield(S, matVar)
            error('MAT file %s does not contain variable "%s".', filePath, matVar);
        end
        M = S.(matVar);

        w = whos('M');
        movieInGB = w.bytes / 1024^3;

    otherwise
        error('Unsupported input "%s". Use .h5/.hdf5 (dataset %s) or .mat (variable %s).', ...
              ext, dsetName, matVar);
end

fprintf('Movie size estimate: %.3f GB\n', movieInGB);
disp('path to save output file:');
disp(savePath);

%setupEXTRACT
M = {filePath, '/mov'};
% display size of movie in RAM to set x and y partitions

info = h5info(filePath, '/mov');

movieInGB = info.Dataspace.Size(1)*info.Dataspace.Size(2)*info.Dataspace.Size(3) * 4 / 1024^3; % assuming single;

disp(movieInGB);
disp('path to save output file:');
disp(savePath);
%% set parameters for extraction

%display GPU engagement
d = gpuDevice;
disp(d.Name);
disp(d.Index);
disp(d.AvailableMemory/2^30);


config=[];
config = get_defaults(config); 
config.avg_cell_radius=avg_cell_radius;
config.trace_output_option=trace_output_option;
config.num_partitions_x=num_partitions;
config.num_partitions_y=num_partitions; 
config.use_gpu=1; 
config.multi_gpu=1; 
config.num_workers=2;
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

parpool('local', config.num_workers);

output=extractor(M,config);

p=gcp('nocreate');
if ~isempty(p)
    idx = zeros(p.NumWorkers,1);
    parfor i = 1:p.NumWorkers
        di = gpuDevice;
        idx(i) = di.Index;
    end
    disp(idx);
end


%%
ts = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
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
