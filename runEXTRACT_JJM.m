%% load motion corrected h5 file and format for EXTRACT

setupEXTRACT
filePath = '/Users/johnmarshall/Documents/Analysis/nVueData/SPRT/SPRT_m1_d6/2024-11-12-15-23-47_channel1_tiff_output/h5_outTestEXTRACT_2.h5';
M = h5read(filePath, '/data');
% display size of movie in RAM to set x and y partitions
info = whos('M');
memoryInGB = info.bytes / (1024^3);
disp(memoryInGB); 
%% set parameters for extraction

config=[];
config = get_defaults(config); 
<<<<<<< HEAD
config.avg_cell_radius=20;
config.trace_output_option='no_constraint';
config.num_partitions_x=4;
config.num_partitions_y=4; 
config.parallel_cpu=0;
config.use_gpu=1; 
config.max_iter = 10; 
config.cellfind_min_snr=8;
config.thresholds.T_min_snr=15;
config.use_sparse_arrays=0;
=======
config.avg_cell_radius=21;
config.trace_output_option='no_constraint';
config.num_partitions_x=4;
config.num_partitions_y=4; 
config.use_gpu=0; 
config.max_iter = 10; 
config.cellfind_min_snr=1;
config.thresholds.T_min_snr=7;
config.use_sparse_arrays=1;
config.thresholds.spatial_corrupt_thresh=2.5; 
>>>>>>> from laptop

%%
%%run EXTRACT
output=extractor(M,config);

%
savePathMATLAB = '/Users/johnmarshall/Documents/Analysis/nVueData/SPRT/SPRT_m1_d6/2024-11-12-15-23-47_channel1_tiff_output/h5_outTestEXTRACT_2_EXTRACTOutput.mat';
save(savePathMATLAB, 'output', '-v7.3');

%savePathh5 = '/Users/johnmarshall/Documents/Analysis/nVueData/SPRT/11_15_59_02_green_EXTRACTOutput.h5';
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
