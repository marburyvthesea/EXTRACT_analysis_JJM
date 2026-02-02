%% load motion corrected h5 file and format for EXTRACT

%% variables passed from command line
%filePath = '/Users/johnmarshall/Documents/Analysis/miniscope_analysis/gray_00denoised00_converted___motion_corrected.h5';
%num_partitions
%savePath = '/Users/johnmarshall/Documents/Analysis/nVueData/SPRT/';
[dir, session] = fileparts(filePath)


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
config.avg_cell_radius=11;
config.trace_output_option='no_constraint';
config.num_partitions_x=num_partitions;
config.num_partitions_y=num_partitions; 
config.use_gpu=1; 
config.multi_gpu=1; 
config.num_workers=2;
config.max_iter = 10; 
config.cellfind_min_snr=9;
config.thresholds.T_min_snr=19;
config.use_sparse_arrays=0;

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
savePathMATLAB = strcat(savePath, session, '.mat');
save(savePathMATLAB, 'output', '-v7.3');
disp('saving:');
disp(savePathMATLAB);

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
