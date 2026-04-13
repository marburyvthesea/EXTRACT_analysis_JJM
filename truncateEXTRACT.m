% Desired frame range (rows of temporal_weights)
t0 = 1500;
t1 = 2500;

% Basic checks
T = output.temporal_weights;
assert(size(T,2) == 861, "Unexpected #cells (cols): %d", size(T,2));
assert(t0 >= 1 && t1 <= size(T,1) && t0 <= t1, "Bad slice range.");

% Slice (1001 x 861)
output.temporal_weights = T(t0:t1, :);

% Optional: sanity print
fprintf("New temporal_weights size: %s\n", mat2str(size(output.temporal_weights)));