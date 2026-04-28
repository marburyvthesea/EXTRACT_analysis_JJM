function mat_to_h5_mov_tds(matPath, h5Path, varName, dsetName, framesPerChunk, castTo, frameStart, frameEnd, downsample_input)
%MAT_TO_H5_MOV_TDS Convert a 3D movie var in a -v7.3 MAT file to HDF5.
%
%   Full conversion:
%     mat_to_h5_mov_tds("in.mat","out.h5","Y","/mov",200,"single")
%
%   Subset conversion with temporal downsampling:
%     mat_to_h5_mov_tds("in.mat","out.h5","Y","/mov",200,"single", 1000, 2000, 2)
%
% Requirements:
%   - matPath should be a -v7.3 MAT-file for chunked matfile slicing.
%
% Notes:
%   - Assumes movie is [height x width x time].
%   - downsample_input = 1 keeps every frame.
%   - downsample_input = N keeps every Nth frame, starting at frameStart.
%   - Output dataset time dimension is numel(frameStart:downsample_input:frameEnd).
%   - Stores MAT frameStart/frameEnd and downsample_input as H5 attributes.

    if nargin < 3 || isempty(varName),         varName = "Y"; end
    if nargin < 4 || isempty(dsetName),       dsetName = "/mov"; end
    if nargin < 5 || isempty(framesPerChunk), framesPerChunk = 200; end
    if nargin < 6,                            castTo = ""; end

    % --- normalize string/char inputs for R2023b ---
    if isstring(varName),  varName  = char(varName);  end
    if isstring(dsetName), dsetName = char(dsetName); end
    if isstring(castTo),   castTo   = char(castTo);   end

    % Inspect variable without loading it
    info = whos('-file', matPath, varName);
    if isempty(info)
        error('Variable "%s" not found in %s', varName, matPath);
    end
    sz = info.size;                 % [H W T]
    clsIn = string(info.class);

    mf = matfile(matPath);          % doesn't load Y
    tmp = mf.(varName)(1,1,1); %#ok<NASGU>
    clear tmp

    if numel(sz) ~= 3
        error('Expected %s to be 3D [H x W x T]. Got size: %s', varName, mat2str(sz));
    end

    H = sz(1); W = sz(2); T = sz(3);

    % Default subset range = full movie
    if nargin < 7 || isempty(frameStart),       frameStart = 1; end
    if nargin < 8 || isempty(frameEnd),         frameEnd   = T; end
    if nargin < 9 || isempty(downsample_input), downsample_input = 1; end

    frameStart = double(frameStart);
    frameEnd = double(frameEnd);
    downsample_input = double(downsample_input);

    if frameStart < 1 || frameStart > T || frameEnd < 1 || frameEnd > T || frameStart > frameEnd
        error('Invalid frame range [%d..%d] for T=%d', frameStart, frameEnd, T);
    end

    if downsample_input < 1 || floor(downsample_input) ~= downsample_input
        error('downsample_input must be a positive integer. Got: %g', downsample_input);
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
               'Original error:\n%s'], varName, ME.message);
    end

    % Recreate output file
    if exist(h5Path, 'file')
        delete(h5Path);
    end

    selectedFrames = frameStart:downsample_input:frameEnd;
    Tout = numel(selectedFrames);
    szOut = [H W Tout];

    % Chunk size: moderate spatial chunks; time chunk clamped to output length
    chunk = [min(H,512), min(W,512), min(Tout,framesPerChunk)];

    fprintf('Input:  %s (%s), size %s\n', matPath, clsIn, mat2str([H W T]));
    fprintf('Subset: frames %d-%d with temporal step %d (Tout=%d)\n', ...
        frameStart, frameEnd, downsample_input, Tout);
    fprintf('Output: %s dataset %s (%s), size %s, chunk %s\n', ...
        h5Path, dsetName, clsOut, mat2str(szOut), mat2str(chunk));

    h5create(h5Path, dsetName, szOut, ...
        'Datatype', char(clsOut), ...
        'ChunkSize', chunk);

    % Metadata / provenance
    h5writeatt(h5Path, dsetName, 'source_mat', char(matPath));
    h5writeatt(h5Path, dsetName, 'source_var', char(varName));
    h5writeatt(h5Path, dsetName, 'created_by', 'mat_to_h5_mov_tds');
    h5writeatt(h5Path, dsetName, 'source_frameStart', int64(frameStart));
    h5writeatt(h5Path, dsetName, 'source_frameEnd', int64(frameEnd));
    h5writeatt(h5Path, dsetName, 'source_downsample_input', int64(downsample_input));

    % Stream write in output-frame chunks using the selected MAT-frame indices.
    for tOut0 = 1:framesPerChunk:Tout
        tOut1 = min(Tout, tOut0 + framesPerChunk - 1);
        idx = selectedFrames(tOut0:tOut1);
        nThis = numel(idx);

        block = mf.(varName)(:,:,idx);

        if clsOut ~= clsIn
            block = cast(block, char(clsOut));
        end

        h5write(h5Path, dsetName, block, [1 1 tOut0], [H W nThis]);
        fprintf('Wrote MAT frames %d-%d with step %d -> H5 frames %d-%d\n', ...
            idx(1), idx(end), downsample_input, tOut0, tOut1);
    end

    fprintf('Done.\n');
end
