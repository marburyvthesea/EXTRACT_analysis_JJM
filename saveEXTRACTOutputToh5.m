

savePathh5 = strcat(savePath, session, '.h5');
fields = fieldnames(output); % Get the field names of the structure
for i = 1:numel(fields)
% Get the data and field name
	fieldName = fields{i};
	data = output.(fieldName);
% Create dataset in the HDF5 file
	h5create(savePathh5, ['/', fieldName], size(data), 'Datatype', class(data));
	% Write data to the dataset
	h5write(savePathh5, ['/', fieldName], data);
end

