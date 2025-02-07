

cnmfe_file = load('/Users/johnmarshall/Documents/Analysis/nVueData/SPRT/08-Dec_21_46_50_out.mat'); 

structActSortFMT = struct();

calciumTraces = cnmfe_file.C; % Renaming "C" to "temporal_weights"
structActSortFMT.temporal_weights = calciumTraces'; 
d1 = cnmfe_file.options.d1;
d2 = cnmfe_file.options.d2;
sz_A = size(cnmfe_file.A);

%
A_full = full(cnmfe_file.A); 
structActSortFMT.spatial_weights = reshape(A_full, [d1, d2, sz_A(1,2)]);  % Renaming "A" to "spatial_weights"

%%
savePathMATLAB = '/Users/johnmarshall/Documents/Analysis/nVueData/SPRT/11_15_59_02_green_EXTRACTOutput_.mat';
save(savePathMATLAB, 'structActSortFMT', '-v7.3');