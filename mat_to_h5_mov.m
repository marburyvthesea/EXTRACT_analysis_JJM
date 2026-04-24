function mat_to_h5_mov(matPath, h5Path, varName, dsetName, framesPerChunk, castTo, frameStart, frameEnd)
%MAT_TO_H5_MOV Convert a 3D movie var in a -v7.3 MAT file to HDF5 dataset.
%
%   Full conversion:
%     mat_to_h5_mov("in.mat","out.h5","Y","/mov",200,"single")
%
%   Subset conversion (frames frameStart..frameEnd from MAT):
%     mat_to_h5_mov("in.mat","out.h5","Y","/mov",200,"single", 1000, 2000)
%
% Requirements:
%   - matPath should be a -v7.3 MAT-file for chunked matfile slicing.
%
% Notes:
%   - Assumes movie is [height x width x time].
%   - Output dataset time dimension is (frameEnd-frameStart+1).
%   - Stores MAT frameStart/frameEnd as H5 attributes for provenance.

    if nargin < 3 || isempty(varName),        varName = "Y"; end
    if nargin < 4 || isempty(dsetName),      dsetName = "/mov"; end
    if nargin < 5 || isempty(framesPerChunk),framesPerChunk = 200; end
    if nargin < 6,                          castTo = ""; end

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

    mf = matfile(matPath);           % doesn't load Y
    tmp = mf.(varName)(1,1,1); %#ok<NASGU>
    clear tmp
    
    if numel(sz) ~= 3
        error('Expected %s to be 3D [H x W x T]. Got size: %s', varName, mat2str(sz));
    end

    H = sz(1); W = sz(2); T = sz(3);

    % Default subset range = full movie
    if nargin < 7 || isempty(frameStart), frameStart = 1; end
    if nargin < 8 || isempty(frameEnd),   frameEnd   = T; end

    frameStart = double(frameStart);
    frameEnd   = double(frameEnd);

    if frameStart < 1 || frameStart > T || frameEnd < 1 || frameEnd > T || frameStart > frameEnd
        error('Invalid frame range [%d..%d] for T=%d', frameStart, frameEnd, T);
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

    Tout = frameEnd - frameStart + 1;
    szOut = [H W Tout];

    % Chunk size: moderate spatial chunks; time chunk clamped to output length
    chunk = [min(H,512), min(W,512), min(Tout,framesPerChunk)];

    fprintf('Input:  %s (%s), size %s\n', matPath, clsIn, mat2str([H W T]));
    fprintf('Subset: frames %d-%d (Tout=%d)\n', frameStart, frameEnd, Tout);
    fprintf('Output: %s dataset %s (%s), size %s, chunk %s\n', ...
        h5Path, dsetName, clsOut, mat2str(szOut), mat2str(chunk));

    h5create(h5Path, dsetName, szOut, ...
        'Datatype', char(clsOut), ...
        'ChunkSize', chunk);

    % Metadata / provenance
    h5writeatt(h5Path, dsetName, 'source_mat',        char(matPath));
    h5writeatt(h5Path, dsetName, 'source_var',        char(varName));
    h5writeatt(h5Path, dsetName, 'created_by',        'mat_to_h5_mov');
    h5writeatt(h5Path, dsetName, 'source_frameStart', int64(frameStart));
    h5writeatt(h5Path, dsetName, 'source_frameEnd',   int64(frameEnd));

    % Stream write in time chunks:
    % MAT indices: t = frameStart..frameEnd
    % H5 indices:  tOut = 1..Tout
    tOut0 = 1;
    for tMat0 = frameStart:framesPerChunk:frameEnd
        tMat1 = min(frameEnd, tMat0 + framesPerChunk - 1);
        nThis = tMat1 - tMat0 + 1;

        block = mf.(varName)(:,:,tMat0:tMat1);

        if clsOut ~= clsIn
            block = cast(block, char(clsOut));
        end

        h5write(h5Path, dsetName, block, [1 1 tOut0], [H W nThis]);
        fprintf('Wrote MAT frames %d-%d -> H5 frames %d-%d\n', ...
            tMat0, tMat1, tOut0, tOut0+nThis-1);

        tOut0 = tOut0 + nThis;
    end

    fprintf('Done.\n');
end
