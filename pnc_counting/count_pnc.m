function [basic_stats, full_stats, images] = count_pnc(subfolder_path, nd2name, debug_on)
% Count the number of PNCs in a given ND2 file
%
% Author: Wei Hong Yeo, 2025. whyeo@u.northwestern.edu
%
% INPUT
% subfolder_path: string
%     Path to the subfolder containing the ND2 file.
% nd2name: string
%     Name of the ND2 file, without the extension.
% debug_on: logical (optional)
%     Whether to display debug information. Default is false.
%
% OUTPUT
% basic_stats: struct
%     Basic statistics of the PNCs.
% full_stats: table
%     Full statistics of the PNCs.
% images: struct
%     Images generated in analysis.
%
% EXAMPLE
% perc = count_pnc('IMG1.nd2');

% check if nd2name contains .nd2
if contains(nd2name, '.nd2')
    nd2name = nd2name(1:end-4);
end

if nargin < 3
    debug_on = false;
end

% positive threshold
positive_threshold = 30;
min_nucleus_area = 5000;
max_nucleus_area = 50000;

% read nd2 file
imdata = nd2read(fullfile('data', subfolder_path, sprintf('%s.nd2', nd2name)));

% get the size of the image
im_size = size(imdata); % XYCZT

ch1 = squeeze(imdata(:,:,1,:));
ch2 = squeeze(imdata(:,:,2,:));

% scale ch1 to 0-1 with double
ch1_max = scale_image(max(ch1,[],3));
ch1 = scale_image(ch1);

% convert values in ch1_max to percentiles
ch1_percentiles = discretize(ch1_max(:),prctile(ch1_max(:),0:100));
ch1_percentiles = reshape(ch1_percentiles,size(ch1_max));

% average project of ch1, max project of ch2
ch1 = mean(ch1,3);
ch2 = max(ch2,[],3);

% threshold ch2
% ch2_thresh = ch2 > quantile(ch2(:), 0.95);
local_thresh = adaptthresh(ch2,0.01,'NeighborhoodSize',7,'Statistic','gaussian');
ch2_thresh = imbinarize(ch2, local_thresh);

% perform segmentation using segment anything, (debug_on = true means verbose)
segmentation_file = fullfile('processed', subfolder_path, sprintf('%s_segmentation.mat', nd2name));

do_segmentation = true;
if exist(segmentation_file, 'file')
    segmentation_data = load(segmentation_file, 'masks', 'min_nucleus_area', 'max_nucleus_area');
    if ~isfield(segmentation_data, 'masks') || ...
            ~isfield(segmentation_data, 'min_nucleus_area') || ...
            ~isfield(segmentation_data, 'max_nucleus_area')

    elseif (segmentation_data.min_nucleus_area ~= min_nucleus_area) || ...
            (segmentation_data.max_nucleus_area ~= max_nucleus_area)

    else
        masks = segmentation_data.masks;
        % clear the segmentation_data variable
        clear segmentation_data;
        do_segmentation = false;
    end
end

if do_segmentation
    masks = imsegsam(ch1_max,...
        'MinObjectArea',min_nucleus_area, ...
        'MaxObjectArea',max_nucleus_area, ...
        'ScoreThreshold',0.7,...
        'Verbose',debug_on);
    save(segmentation_file, 'masks', 'min_nucleus_area', 'max_nucleus_area');
end

% get statistics of the mask sizes
im_size = im_size(1:2); % only XY is relevant
n_masks = length(masks.PixelIdxList);

mask_area_all = zeros(1,n_masks);
for ii = 1:n_masks
    mask_area_all(ii) = length(masks.PixelIdxList{ii});
end

% sort masks by increasing area
[~, sortidx] = sort(mask_area_all);

mask_stats_vars = {'MaskID', 'Area', 'Smoothness', ...
    'PercentileIntensity_IQR', 'PercentileIntensity_Mean', 'PercentileIntensity_Std', ...
    'MeanIntensity_IQR', 'MeanIntensity_Mean', 'MeanIntensity_Std', ...
    'MaxIntensity_IQR', 'MaxIntensity_Mean', 'MaxIntensity_Std', ...
    'CentroidX', 'CentroidY', 'Circularity', 'Eccentricity', 'Solidity', ...
    'NumberCh2PixelsPositive'};
mask_stats = array2table(zeros(length(sortidx),length(mask_stats_vars)), 'VariableNames', mask_stats_vars);

mask_overall = zeros(im_size);
mask_positive = zeros(im_size);
mask_negative = zeros(im_size);
mask_bad = zeros(im_size);

n_positive = 0;
n_negative = 0;
n_bad = 0;

% load the SVM model which predicts which masks are bad (bad masks Y = 1)
load('svm_model.mat', 'svm_model', 'svm_features', 'svm_mean', 'svm_std');

jj = 1;
for ii = 1:length(sortidx)
    mask_current = zeros(im_size);
    if sum(mask_overall(masks.PixelIdxList{sortidx(ii)}) > 0) > (0.1 * length(masks.PixelIdxList{sortidx(ii)}))
        % i.e., if the more than 10% of the mask is already assigned to another mask
        continue;
    end

    % calculate the smoothness of the mask
    mask_current(masks.PixelIdxList{sortidx(ii)}) = 1;
    mask_stats{jj, 'MaskID'} = jj;
    mask_stats{jj, 'Area'} = sum(mask_current(:));
    mask_stats{jj, 'Smoothness'} = smoothness(mask_current,20);

    ch1_percentiles_mask = ch1_percentiles(masks.PixelIdxList{sortidx(ii)});
    mask_stats{jj, 'PercentileIntensity_IQR'} = iqr(ch1_percentiles_mask);
    mask_stats{jj, 'PercentileIntensity_Mean'} = mean(ch1_percentiles_mask);
    mask_stats{jj, 'PercentileIntensity_Std'} = std(ch1_percentiles_mask);

    ch1_mean_mask = ch1(masks.PixelIdxList{sortidx(ii)});
    mask_stats{jj, 'MeanIntensity_IQR'} = iqr(ch1_mean_mask);
    mask_stats{jj, 'MeanIntensity_Mean'} = mean(ch1_mean_mask);
    mask_stats{jj, 'MeanIntensity_Std'} = std(ch1_mean_mask);

    ch1_max_mask = double(ch1_max(masks.PixelIdxList{sortidx(ii)}));
    mask_stats{jj, 'MaxIntensity_IQR'} = iqr(ch1_max_mask);
    mask_stats{jj, 'MaxIntensity_Mean'} = mean(ch1_max_mask);
    mask_stats{jj, 'MaxIntensity_Std'} = std(ch1_max_mask);

    % get the circularity, eccentricity, and solidity of the mask
    mask_props = regionprops(mask_current, 'Circularity', 'Eccentricity', 'Solidity');
    mask_stats{jj, 'Circularity'} = mask_props.Circularity;
    mask_stats{jj, 'Eccentricity'} = mask_props.Eccentricity;
    mask_stats{jj, 'Solidity'} = mask_props.Solidity;

    % get the x and y coordinates of the mask
    [yy, xx] = ind2sub(im_size, masks.PixelIdxList{sortidx(ii)});
    mask_stats{jj, 'CentroidX'} = mean(xx);
    mask_stats{jj, 'CentroidY'} = mean(yy);

    % get the number of ch2 pixels in the mask
    mask_ch2 = ch2_thresh(masks.PixelIdxList{sortidx(ii)});
    mask_stats{jj, 'NumberCh2PixelsPositive'} = sum(mask_ch2);

    % use the SVM model to predict which masks are bad (bad masks Y = 1)
    X = mask_stats{jj, svm_features};
    X = (X - svm_mean) ./ svm_std;
    mask_stats{jj, 'BadMask'} = predict(svm_model, X);

    if mask_stats{jj, 'BadMask'} == 0
        mask_overall(masks.PixelIdxList{sortidx(ii)}) = jj;

        if sum(mask_ch2) >= positive_threshold
            mask_positive(masks.PixelIdxList{sortidx(ii)}) = jj;
            n_positive = n_positive + 1;
        else
            mask_negative(masks.PixelIdxList{sortidx(ii)}) = jj;
            n_negative = n_negative + 1;
        end

    else
        mask_bad(masks.PixelIdxList{sortidx(ii)}) = jj;
        n_bad = n_bad + 1;
    end
    
    jj = jj + 1;
end

n_masks = jj - 1;
n_total = n_positive + n_negative;
mask_stats = mask_stats(1:n_masks,:);

perc = n_positive / n_total * 100;
basic_stats.percentage = perc;
basic_stats.n_negative = n_negative;
basic_stats.n_positive = n_positive;
basic_stats.n_bad = n_bad;
basic_stats.n_total = n_total;
basic_stats.n_masks = n_masks;

full_stats = mask_stats;

images.ch1_max = ch1_max;
images.ch1 = ch1;
images.ch2 = ch2;
images.ch2_thresh = ch2_thresh;
images.labelMatrix = labelmatrix(masks);
images.mask_overall = mask_overall;
images.mask_positive = mask_positive;
images.mask_negative = mask_negative;
images.mask_bad = mask_bad;

end

function val = smoothness(mask, sigma)
% Calculate the smoothness of a mask
%
% INPUT
% mask: logical
%     Binary mask.
% sigma: double (optional)
%     Standard deviation of the Gaussian filter. Default is 10.
%
% OUTPUT
% smoothness: double
%     Smoothness of the mask in terms of the intersection over union.
%     Range of values is [0,1], where 1 is the smoothest.
%
% EXAMPLE
% val = smoothness(mask);

if nargin < 2
    sigma = 20;
end

mask_smooth = imgaussfilt(double(mask),sigma);
mask_smooth = mask_smooth > 0.5;

% Compute the intersection and union of the masks
intersection = sum(mask(:) & mask_smooth(:));
union = sum(mask(:) | mask_smooth(:));

% Calculate IoU (intersection over union)
val = intersection / union;

end


function imdata = scale_image(imdata)
    % scale imdata to 0-1
    imdata = double(imdata);
    imdata = (imdata - min(imdata(:))) / (max(imdata(:)) - min(imdata(:)));
    % convert to 8-bit
    imdata = uint8(imdata * 255);
end