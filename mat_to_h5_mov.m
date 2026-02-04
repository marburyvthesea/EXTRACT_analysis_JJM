function mat_to_h5_mov(matPath, h5Path, varName, dsetName, framesPerChunk, castTo)
%MAT_TO_H5_MOV Convert a 3D movie var in a -v7.3 MAT file to HDF5 dataset.
%
%   mat_to_h5_mov("in.mat","out.h5","Y","/mov",200,"single")
%
% Requirements:
%   - matPath must be a -v7.3 MAT-file if you want chunked reading.
%
% Notes:
%   - Assumes movie is [height x width x time].
%   - Writes HDF5 dataset with chunking for efficient partial reads.

    if nargin < 3 || isempty(varName), varName = "Y"; end
    if nargin < 4 || isempty(dsetName), dsetName = "/mov"; end
    if nargin < 5 || isempty(framesPerChunk), framesPerChunk = 200; end
    if nargin < 6, castTo = ""; end

    % Inspect variable without loading it
    info = whos('-file', matPath, varName);
    if isempty(info)
        error('Variable "%s" not found in %s', varName, matPath);
    end
    sz = info.size;
    clsIn = string(info.class);

    if numel(sz) ~= 3
        error('Expected %s to be 3D [H x W x T]. Got size: %s', varName, mat2str(sz));
    end

    % Determine output datatype
    if castTo ~= ""
        clsOut = string(castTo);
    else
        clsOut = clsIn;
    end

    % Test that matfile supports slicing (requires -v7.3)
    try
        mf = matfile(matPath);
        tmp = mf.(varName)(1,1,1); %#ok<NASGU>
	clear tmp
    catch ME
        error(['Cannot slice "%s" via matfile. This usually means the MAT-file is not -v7.3.\n' ...
               'Either re-save it as -v7.3 (may require loading into RAM) or convert using a different tool.\n\nOriginal error:\n%s'], ...
              varName, ME.message);
    end

    % Recreate output file
    if exist(h5Path, 'file')
        delete(h5Path);
    end

    H = sz(1); W = sz(2); T = sz(3);

    % Chunk size: keep spatial chunks moderate, time chunk = framesPerChunk (clamped)
    chunk = [min(H,512), min(W,512), min(T,framesPerChunk)];

    fprintf('Input:  %s (%s), size %s\n', matPath, clsIn, mat2str(sz));
    fprintf('Output: %s dataset %s (%s), chunk %s\n', h5Path, dsetName, clsOut, mat2str(chunk));

    h5create(h5Path, dsetName, sz, ...
        'Datatype', char(clsOut), ...
        'ChunkSize', chunk);

    % Optional metadata
    h5writeatt(h5Path, dsetName, 'source_mat', char(matPath));
    h5writeatt(h5Path, dsetName, 'source_var', char(varName));
    h5writeatt(h5Path, dsetName, 'created_by', 'mat_to_h5_mov');

    % Stream write in time chunks
    for t0 = 1:framesPerChunk:T
        t1 = min(T, t0 + framesPerChunk - 1);

        block = mf.(varName)(:,:,t0:t1);

        if clsOut ~= clsIn
            block = cast(block, char(clsOut));
        end

        h5write(h5Path, dsetName, block, [1 1 t0], [H W (t1-t0+1)]);
        fprintf('Wrote frames %d-%d / %d\n', t0, t1, T);
    end

    fprintf('Done.\n');
end

