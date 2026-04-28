function mat_to_h5_mov_tds(matPath, h5Path, varName, dsetName, framesPerChunk, castTo, frameStart, frameEnd, downsample_input, deflateLevel)
%MAT_TO_H5_MOV_TDS Convert a 3D movie var in a -v7.3 MAT file to HDF5.
%
%   Full conversion:
%     mat_to_h5_mov_tds("in.mat","out.h5","Y","/mov",200,"single")
%
%   Subset conversion with temporal downsampling:
%     mat_to_h5_mov_tds("in.mat","out.h5","Y","/mov",200,"single", 1000, 2000, 2)
%
%   FIJI-friendly viewing export:
%     mat_to_h5_mov_tds("in.mat","out.h5","Y","/mov",200,"uint16_scaled", [], [], 2, 4)
%
% Requirements:
%   - matPath should be a -v7.3 MAT-file for chunked matfile slicing.
%
% Notes:
%   - Assumes movie is [height x width x time].
%   - downsample_input = 1 keeps every frame.
%   - downsample_input = N keeps every Nth frame, starting at frameStart.
%   - castTo = "uint16_scaled" rescales the selected movie range to uint16.
%   - deflateLevel = 0 disables HDF5 gzip compression; 1-9 enables it.
%   - Output dataset time dimension is numel(frameStart:downsample_input:frameEnd).
%   - Stores MAT frameStart/frameEnd, downsample_input, and compression as H5 attributes.

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
    if nargin < 10 || isempty(deflateLevel),    deflateLevel = 0; end

    frameStart = double(frameStart);
    frameEnd = double(frameEnd);
    downsample_input = double(downsample_input);
    deflateLevel = double(deflateLevel);

    if frameStart < 1 || frameStart > T || frameEnd < 1 || frameEnd > T || frameStart > frameEnd
        error('Invalid frame range [%d..%d] for T=%d', frameStart, frameEnd, T);
    end

    if downsample_input < 1 || floor(downsample_input) ~= downsample_input
        error('downsample_input must be a positive integer. Got: %g', downsample_input);
    end

    if deflateLevel < 0 || deflateLevel > 9 || floor(deflateLevel) ~= deflateLevel
        error('deflateLevel must be an integer from 0 to 9. Got: %g', deflateLevel);
    end

    castModeScaled = strcmpi(strtrim(castTo), 'uint16_scaled');

    % Determine output datatype
    if castModeScaled
        clsOut = "uint16";
    elseif ~isempty(castTo)
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
    scaleMin = [];
    scaleMax = [];

    % Chunk size: moderate spatial chunks; time chunk clamped to output length
    chunk = [min(H,512), min(W,512), min(Tout,framesPerChunk)];

    if castModeScaled
        fprintf('Scanning selected frames to compute uint16 scaling range...\n');
        scaleMin = inf;
        scaleMax = -inf;
        for tOut0 = 1:framesPerChunk:Tout
            tOut1 = min(Tout, tOut0 + framesPerChunk - 1);
            idx = selectedFrames(tOut0:tOut1);
            block = mf.(varName)(:,:,idx);
            scaleMin = min(scaleMin, double(min(block, [], 'all')));
            scaleMax = max(scaleMax, double(max(block, [], 'all')));
        end
    end

    fprintf('Input:  %s (%s), size %s\n', matPath, clsIn, mat2str([H W T]));
    fprintf('Subset: frames %d-%d with temporal step %d (Tout=%d)\n', ...
        frameStart, frameEnd, downsample_input, Tout);
    fprintf('Output: %s dataset %s (%s), size %s, chunk %s, deflate %d\n', ...
        h5Path, dsetName, clsOut, mat2str(szOut), mat2str(chunk), deflateLevel);
    if castModeScaled
        fprintf('uint16 scaling range: [%g, %g]\n', scaleMin, scaleMax);
    end

    if deflateLevel > 0
        h5create(h5Path, dsetName, szOut, ...
            'Datatype', char(clsOut), ...
            'ChunkSize', chunk, ...
            'Deflate', deflateLevel);
    else
        h5create(h5Path, dsetName, szOut, ...
            'Datatype', char(clsOut), ...
            'ChunkSize', chunk);
    end

    % Metadata / provenance
    h5writeatt(h5Path, dsetName, 'source_mat', char(matPath));
    h5writeatt(h5Path, dsetName, 'source_var', char(varName));
    h5writeatt(h5Path, dsetName, 'created_by', 'mat_to_h5_mov_tds');
    h5writeatt(h5Path, dsetName, 'source_frameStart', int64(frameStart));
    h5writeatt(h5Path, dsetName, 'source_frameEnd', int64(frameEnd));
    h5writeatt(h5Path, dsetName, 'source_downsample_input', int64(downsample_input));
    h5writeatt(h5Path, dsetName, 'h5_deflate_level', int64(deflateLevel));
    if castModeScaled
        h5writeatt(h5Path, dsetName, 'cast_mode', 'uint16_scaled');
        h5writeatt(h5Path, dsetName, 'scale_min', scaleMin);
        h5writeatt(h5Path, dsetName, 'scale_max', scaleMax);
    end

    % Stream write in output-frame chunks using the selected MAT-frame indices.
    for tOut0 = 1:framesPerChunk:Tout
        tOut1 = min(Tout, tOut0 + framesPerChunk - 1);
        idx = selectedFrames(tOut0:tOut1);
        nThis = numel(idx);

        block = mf.(varName)(:,:,idx);

        if castModeScaled
            block = scale_block_to_uint16(block, scaleMin, scaleMax);
        elseif clsOut ~= clsIn
            block = cast(block, char(clsOut));
        end

        h5write(h5Path, dsetName, block, [1 1 tOut0], [H W nThis]);
        fprintf('Wrote MAT frames %d-%d with step %d -> H5 frames %d-%d\n', ...
            idx(1), idx(end), downsample_input, tOut0, tOut1);
    end

    fprintf('Done.\n');
end

function blockOut = scale_block_to_uint16(blockIn, scaleMin, scaleMax)
    if scaleMax <= scaleMin
        blockOut = zeros(size(blockIn), 'uint16');
        return
    end

    blockOut = double(blockIn);
    blockOut = (blockOut - scaleMin) .* (65535 / (scaleMax - scaleMin));
    blockOut = min(max(blockOut, 0), 65535);
    blockOut = uint16(round(blockOut));
end
