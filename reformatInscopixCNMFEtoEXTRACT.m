

cnmfeOutput = '/Users/johnmarshall/Documents/Analysis/miniscope_analysis/miniscopeLinearTrack/cell_traces_mouse1day1 copy.csv'; 
folderWithCellImages = '/Users/johnmarshall/Documents/Analysis/miniscope_analysis/loadTest';
cnmfe = readtable(cnmfeOutput);
celltraces = table2array(cnmfe);
celltraces = (:,2:);

structActSortFMT = struct();
structActSortFMT.temporal_weights = celltraces'; % Renaming "C" to "temporal_weights"

%%
% Get a list of all image files in the current folder
imageFiles = dir(fullfile(folderWithCellImages, '*.tiff'));
%
numImages = length(imageFiles); % Total number of images
    
% Read the first image to determine the dimensions
firstImage = imread(fullfile(folderWithCellImages, imageFiles(1).name));
[height, width] = size(firstImage);
    
% Preallocate a 3D array for the images
imageStack = zeros(height, width, numImages, 'like', firstImage);
imagesFlat = zeros(height*width, numImages); 

% Load all images into the 3D array
for i = 1:length(numImages)
    imageIdx = numImages(1, i); 
    % Read the image
    currentImage = imread(fullfile(folderWithCellImages, imageFiles(imageIdx).name));
    currentImage1D = currentImage(:);
    imagesFlat(:,i) = currentImage1D; 

    % Store the image in the 3D array
    imageStack(:, :, i) = currentImage;

end
    

structActSortFMT.spatial_weights = imagesFlat;  % Renaming "A" to "spatial_weights"

%%
savePathMATLAB = '/Users/johnmarshall/Documents/Analysis/nVueData/SPRT/11_15_59_02_green_EXTRACTOutput.mat';
save(savePathMATLAB, 'output', '-v7.3');