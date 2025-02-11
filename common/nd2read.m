function data = nd2read(filename, datatype)
% ND2READ reads data from a Nikon ND2 file.
%
% Written by: Wei Hong Yeo, 2025. whyeo@u.northwestern.edu
%
% INPUT
% filename: string
%     The name of the ND2 file.
% datatype: string (optional)
%     The data type of the image data. Default is 'uint16'.
%
% OUTPUT
% data: image data
%     The image data from the ND2 file, with dimensions (height, width,
%     channels, z-stacks, timepoints).
% 
% Note: This function requires the Bio-Formats library to be installed.
% The Bio-Formats library can be downloaded from
% https://www.openmicroscopy.org/bio-formats/downloads/.
%
% Example:
% data = nd2read('IMG1.nd2');
% 

% Check if the Bio-Formats library is installed
if ~exist('bfopen', 'file')
    error('Bio-Formats library is not installed. Please download it from https://www.openmicroscopy.org/bio-formats/downloads/.');
end

if nargin < 2
    datatype = 'uint16';
end

% Read the ND2 file
imdata = bfopen(filename);

% get the size of the image
im_size = size(imdata{1}{1});

% get the number of z-stacks and channels
n_stacks = size(imdata{1}, 1);
metadata = imdata{1}{1,2};

% read the number of z-stacks, channels, and timepoints from the metadata
z_stack = regexp(metadata, 'Z=(\d+)/(\d+)', 'tokens');
if isempty(z_stack)
    n_zstacks = 1;
else
    n_zstacks = str2double(z_stack{1}{2});
end
c_stack = regexp(metadata, 'C=(\d+)/(\d+)', 'tokens');
if isempty(c_stack)
    n_channels = 1;
else
    n_channels = str2double(c_stack{1}{2});
end
t_stack = regexp(metadata, 'T=(\d+)/(\d+)', 'tokens');
if isempty(t_stack)
    n_timepoints = 1;
else
    n_timepoints = str2double(t_stack{1}{2});
end

% initialize the data structure
data = zeros(im_size(1), im_size(2), n_channels, n_zstacks, n_timepoints, datatype);

for ii = 1:n_stacks
    % get the z-stack, channel, and timepoint
    z_stack = regexp(imdata{1}{ii,2}, 'Z=(\d+)', 'tokens');
    if isempty(z_stack)
        z_stack = 1;
    else
        z_stack = str2double(z_stack{1}{1});
    end
    c_stack = regexp(imdata{1}{ii,2}, 'C=(\d+)', 'tokens');
    if isempty(c_stack)
        c_stack = 1;
    else
        c_stack = str2double(c_stack{1}{1});
    end
    t_stack = regexp(imdata{1}{ii,2}, 'T=(\d+)', 'tokens');
    if isempty(t_stack)
        t_stack = 1;
    else
        t_stack = str2double(t_stack{1}{1});
    end
    
    % read the image data
    data(:,:,c_stack,z_stack,t_stack) = imdata{1}{ii,1};
end

end