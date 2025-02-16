classdef pncCounter < matlab.apps.AppBase
% Count the number of PNCs in a given ND2 file
%
% Author: Wei Hong Yeo, 2025. whyeo@u.northwestern.edu
%

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                      matlab.ui.Figure
        GridLayout                    matlab.ui.container.GridLayout
        SaveVisualizationsButton      matlab.ui.control.Button
        VisualizeButton               matlab.ui.control.Button
        SettingsPanel                 matlab.ui.container.Panel
        GridLayout2                   matlab.ui.container.GridLayout
        SaveSegmentationResultsCheckBox  matlab.ui.control.CheckBox
        SaveSegmentationResultsFolderButton  matlab.ui.control.Button
        GlobalThresholdButton         matlab.ui.control.Button
        ImageThresholdEditField       matlab.ui.control.NumericEditField
        ImageThresholdEditFieldLabel  matlab.ui.control.Label
        ImageThresholdSlider          matlab.ui.control.Slider
        PixelSizeThresholdEditField   matlab.ui.control.NumericEditField
        PixelSizeThresholdEditFieldLabel  matlab.ui.control.Label
        PixelSizeThresholdSlider      matlab.ui.control.Slider
        ImportSettingsButton          matlab.ui.control.Button
        ExportSettingsButton          matlab.ui.control.Button
        ProcessButton                 matlab.ui.control.Button
        InputFolderButton             matlab.ui.control.Button
        ExportTableButton             matlab.ui.control.Button
        UITable                       matlab.ui.control.Table
    end

    % Internal properties and variables
    properties (Access = public) % public for testing
        ImageFolder = '';
        SegmentationResultsFolder = '';

        % Cell array to store the intermediate results and final results
        Results = {};
        Images = {};
        Masks = {};

        % State variables
        State = struct( ...
            'isProcessing', false, ...
            'isCancelled', false, ...
            'isProcessed', false, ...
            'useGlobalThreshold', false, ...
            'settingsChanged', false, ...
            'isLoaded', false);

        % SVM model
        SVMModel = [];

        % variables
        GlobalThreshold = 70;
        LocalThreshold = 90;
        PixelSizeThreshold = 10;
    end

    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)
            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 450 600];
            app.UIFigure.Name = 'PNC Counter';

            % Create GridLayout
            app.GridLayout = uigridlayout(app.UIFigure);
            app.GridLayout.RowHeight = {40, 220, '1x', 40};

            % Create UITable
            app.UITable = uitable(app.GridLayout);
            app.UITable.ColumnName = {'Filename'; 'PNC+'; 'Count'; 'Percent'};
            app.UITable.ColumnWidth = {'1x', 50, 50, 60};
            app.UITable.RowName = {};
            app.UITable.Multiselect = 'off';
            app.UITable.Layout.Row = 3;
            app.UITable.Layout.Column = [1 4];
            app.UITable.Enable = 'off';
            % Link table cell selection to enable/disable Visualize button
            app.UITable.CellSelectionCallback = createCallbackFcn(app, @UITableCellSelection, true);

            % Create InputFolderButton
            app.InputFolderButton = uibutton(app.GridLayout, 'push');
            app.InputFolderButton.Layout.Row = 1;
            app.InputFolderButton.Layout.Column = [1 4];
            app.InputFolderButton.Text = 'Select Input Folder';
            app.InputFolderButton.ButtonPushedFcn = createCallbackFcn(app, @InputFolderButtonPushed, true);

            % Create SettingsPanel
            app.SettingsPanel = uipanel(app.GridLayout);
            app.SettingsPanel.Title = 'Settings';
            app.SettingsPanel.Layout.Row = 2;
            app.SettingsPanel.Layout.Column = [1 4];
            app.SettingsPanel.FontWeight = 'bold';
            app.SettingsPanel.Enable = 'off';

            % Create GridLayout2 for settings
            GridLayout2_RowSpace = 10;
            app.GridLayout2 = uigridlayout(app.SettingsPanel);
            app.GridLayout2.ColumnWidth = {'1x', '1x', '1x'};
            app.GridLayout2.RowHeight = {'1x', GridLayout2_RowSpace, ...
                '1x', '1x', GridLayout2_RowSpace, '1x', '1x', GridLayout2_RowSpace, '1x'};
            app.GridLayout2.RowSpacing = 0;
            
            % Create SaveSegmentationResultsCheckBox
            app.SaveSegmentationResultsCheckBox = uicheckbox(app.GridLayout2);
            app.SaveSegmentationResultsCheckBox.Layout.Row = 1;
            app.SaveSegmentationResultsCheckBox.Layout.Column = [1,2];
            app.SaveSegmentationResultsCheckBox.Text = 'Save Segmentation Results';
            app.SaveSegmentationResultsCheckBox.Value = true;
            app.SaveSegmentationResultsCheckBox.ValueChangedFcn = createCallbackFcn(app, @SaveSegmentationResultsCheckBoxValueChanged, true);

            % Create SaveSegmentationResultsFolderButton
            app.SaveSegmentationResultsFolderButton = uibutton(app.GridLayout2, 'push');
            app.SaveSegmentationResultsFolderButton.Layout.Row = 1;
            app.SaveSegmentationResultsFolderButton.Layout.Column = 3;
            app.SaveSegmentationResultsFolderButton.Text = 'Browse Folder';
            app.SaveSegmentationResultsFolderButton.Enable = 'on';
            app.SaveSegmentationResultsFolderButton.ButtonPushedFcn = createCallbackFcn(app, @SaveSegmentationResultsFolderButtonPushed, true);

            % Create GlobalThresholdButton
            app.GlobalThresholdButton = uibutton(app.GridLayout2);
            app.GlobalThresholdButton.Layout.Row = 3;
            app.GlobalThresholdButton.Layout.Column = 1;
            app.GlobalThresholdButton.Text = 'Local Threshold';
            app.GlobalThresholdButton.ButtonPushedFcn = createCallbackFcn(app, @GlobalThresholdButtonPushed, true);

            % Create ImageThresholdSlider and link its callback
            app.ImageThresholdSlider = uislider(app.GridLayout2);
            app.ImageThresholdSlider.Layout.Row = [3,4];
            app.ImageThresholdSlider.Layout.Column = [2,3];
            app.ImageThresholdSlider.ValueChangedFcn = createCallbackFcn(app, @ImageThresholdSliderValueChanged, true);
            app.ImageThresholdSlider.MajorTicks = 0:20:100;
            app.ImageThresholdSlider.Value = app.LocalThreshold;
            app.ImageThresholdSlider.Limits = [0 100];
            app.ImageThresholdSlider.MajorTickLabels = string(app.ImageThresholdSlider.MajorTicks);
            app.ImageThresholdSlider.MinorTicks = 0:10:100;

            % Create ImageThresholdEditField and link its callback
            app.ImageThresholdEditField = uieditfield(app.GridLayout2, 'numeric');
            app.ImageThresholdEditField.Layout.Row = 4;
            app.ImageThresholdEditField.Layout.Column = 1;
            app.ImageThresholdEditField.ValueChangedFcn = createCallbackFcn(app, @ImageThresholdEditFieldValueChanged, true);
            app.ImageThresholdEditField.Value = app.LocalThreshold;

            % Create PixelSizeThresholdSlider and link its callback
            app.PixelSizeThresholdSlider = uislider(app.GridLayout2);
            app.PixelSizeThresholdSlider.Layout.Row = [6,7];
            app.PixelSizeThresholdSlider.Layout.Column = [2,3];
            app.PixelSizeThresholdSlider.ValueChangedFcn = createCallbackFcn(app, @PixelSizeThresholdSliderValueChanged, true);
            app.PixelSizeThresholdSlider.MajorTicks = 0:20:100;
            app.PixelSizeThresholdSlider.Value = app.PixelSizeThreshold;
            app.PixelSizeThresholdSlider.Limits = [0 100];
            app.PixelSizeThresholdSlider.MajorTickLabels = string(app.PixelSizeThresholdSlider.MajorTicks);
            app.PixelSizeThresholdSlider.MinorTicks = 0:10:100;

            % Create PixelSizeThresholdEditFieldLabel
            app.PixelSizeThresholdEditFieldLabel = uilabel(app.GridLayout2);
            app.PixelSizeThresholdEditFieldLabel.Layout.Row = 6;
            app.PixelSizeThresholdEditFieldLabel.Layout.Column = 1;
            app.PixelSizeThresholdEditFieldLabel.Text = 'Pixel Size Threshold';

            % Create PixelSizeThresholdEditField and link its callback
            app.PixelSizeThresholdEditField = uieditfield(app.GridLayout2, 'numeric');
            app.PixelSizeThresholdEditField.Layout.Row = 7;
            app.PixelSizeThresholdEditField.Layout.Column = 1;
            app.PixelSizeThresholdEditField.ValueChangedFcn = createCallbackFcn(app, @PixelSizeThresholdEditFieldValueChanged, true);
            app.PixelSizeThresholdEditField.Value = app.PixelSizeThreshold;

            % Create ImportSettingsButton
            app.ImportSettingsButton = uibutton(app.GridLayout2, 'push');
            app.ImportSettingsButton.Layout.Row = 9;
            app.ImportSettingsButton.Layout.Column = 2;
            app.ImportSettingsButton.Text = 'Import Settings';
            app.ImportSettingsButton.Enable = 'off';

            % Create ExportSettingsButton
            app.ExportSettingsButton = uibutton(app.GridLayout2, 'push');
            app.ExportSettingsButton.Layout.Row = 9;
            app.ExportSettingsButton.Layout.Column = 3;
            app.ExportSettingsButton.Text = 'Export Settings';
            app.ExportSettingsButton.Enable = 'off';

            % Create ProcessButton
            app.ProcessButton = uibutton(app.GridLayout, 'push');
            app.ProcessButton.Layout.Row = 4;
            app.ProcessButton.Layout.Column = 1;
            app.ProcessButton.Text = 'Process All';
            app.ProcessButton.ButtonPushedFcn = createCallbackFcn(app, @ProcessButtonPushed, true);
            app.ProcessButton.Enable = 'off';

            % Create VisualizeButton (initially disabled)
            app.VisualizeButton = uibutton(app.GridLayout, 'push');
            app.VisualizeButton.Layout.Row = 4;
            app.VisualizeButton.Layout.Column = 2;
            app.VisualizeButton.Text = 'Visualize';
            app.VisualizeButton.ButtonPushedFcn = createCallbackFcn(app, @VisualizeButtonPushed, true);
            app.VisualizeButton.Enable = 'off';

            % Create ExportTableButton
            app.ExportTableButton = uibutton(app.GridLayout, 'push');
            app.ExportTableButton.Layout.Row = 4;
            app.ExportTableButton.Layout.Column = 3;
            app.ExportTableButton.Text = 'Export Table';
            app.ExportTableButton.Enable = 'off';
            app.ExportTableButton.ButtonPushedFcn = createCallbackFcn(app, @ExportTableButtonPushed, true);

            % Create SaveVisualizationsButton
            app.SaveVisualizationsButton = uibutton(app.GridLayout, 'push');
            app.SaveVisualizationsButton.Layout.Row = 4;
            app.SaveVisualizationsButton.Layout.Column = 4;
            app.SaveVisualizationsButton.Text = 'Save Images';
            app.SaveVisualizationsButton.Enable = 'off';
            app.SaveVisualizationsButton.ButtonPushedFcn = createCallbackFcn(app, @SaveVisualizationsButtonPushed, true);

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end

        %% Callback functions

        % Callback for InputFolderButton: opens a folder and loads file names into the UITable
        function InputFolderButtonPushed(app, ~)
            folder = uigetdir;
            app.ImageFolder = folder;
            if folder ~= 0
                % List files (excluding directories)
                files = dir(folder);
                files = files(~[files.isdir]);
                fileNames = {files.name}';
                % filter filenames to only include .nd2 files
                fileNames = fileNames(endsWith(fileNames, '.nd2'));

                % Create dummy columns for Fraction and Status
                dummyPositive = repmat({''}, numel(fileNames), 1);
                dummyTotal = repmat({''}, numel(fileNames), 1);
                dummyFraction = repmat({''}, numel(fileNames), 1);
                app.UITable.Data = [fileNames, dummyPositive, dummyTotal, dummyFraction];

                % initialize a cell array to store the intermediate results and final results
                app.Results = cell(numel(fileNames), 2);
                app.Images = cell(numel(fileNames), 1);
                app.Masks = cell(numel(fileNames), 1);

                % Load all the images in the folder into app.Images
                for i_image = 1:numel(fileNames)
                    filename = fileNames{i_image};
                    if ~isempty(filename)
                        image = app.loadImages(fullfile(app.ImageFolder, filename));
                        app.Images{i_image} = image;
                    end
                end

                % Enable the Process button
                app.State.isLoaded = true;
                app.updateInterface();
            end
        end

        % Callback for ProcessButton: processes all images in the table (for now, just the first image)
        function ProcessButtonPushed(app, ~)
            app.State.isProcessing = true;
            app.State.isProcessed = false;
            app.updateInterface();

            % if there is a single file selected, process that file
            if ~isempty(app.UITable.Selection)
                selectedRow = app.UITable.Selection(1,1);
                app.processImage(selectedRow);
            else
                % process all images
                for i_file = 1:size(app.UITable.Data, 1)
                    app.processImage(i_file);
                end
            end

            % update the state and buttons
            app.State.isProcessing = false;
            app.State.isProcessed = true;
            app.updateInterface();
        end

        % Callback for SaveSegmentationResultsCheckBox: enables/disables the Browse button
        function SaveSegmentationResultsCheckBoxValueChanged(app, ~)
            if app.SaveSegmentationResultsCheckBox.Value
                app.SaveSegmentationResultsFolderButton.Enable = 'on';
                % set default segmentation results folder as the image folder
                app.SegmentationResultsFolder = app.ImageFolder;
            else
                app.SaveSegmentationResultsFolderButton.Enable = 'off';
            end
        end

        % Callback for SaveSegmentationResultsFolderButton: opens a folder to save Segmentation results
        function SaveSegmentationResultsFolderButtonPushed(app, ~)
            folder = uigetdir;
            if folder ~= 0
                % Save the folder path
                app.SegmentationResultsFolder = folder;
            end
        end

        % Callback for GlobalThresholdButton: toggles between Global and Local threshold
        function GlobalThresholdButtonPushed(app, ~)
            app.State.useGlobalThreshold = ~app.State.useGlobalThreshold;
            if app.State.useGlobalThreshold
                app.GlobalThresholdButton.Text = 'Global Threshold';
                app.ImageThresholdEditField.Value = app.GlobalThreshold;
                app.ImageThresholdSlider.Value = app.GlobalThreshold;
            else
                app.GlobalThresholdButton.Text = 'Local Threshold';
                app.ImageThresholdEditField.Value = app.LocalThreshold;
                app.ImageThresholdSlider.Value = app.LocalThreshold;
            end
            app.rethresholdImages();
            app.State.isProcessed = false;
            app.updateInterface();
        end


        % Callback for PixelSizeThresholdSlider: updates the edit field value
        function PixelSizeThresholdSliderValueChanged(app, ~)
            % Round the slider value to the nearest integer
            roundedValue = round(app.PixelSizeThresholdSlider.Value);
            roundedValue = max(1, roundedValue);
            roundedValue = min(app.PixelSizeThresholdSlider.Limits(2), roundedValue);

            app.PixelSizeThresholdSlider.Value = roundedValue;
            app.PixelSizeThresholdEditField.Value = roundedValue;

            app.State.isProcessed = false;
            app.updateInterface();
        end

        % Callback for PixelSizeThresholdEditField: updates the slider value
        function PixelSizeThresholdEditFieldValueChanged(app, ~)
            % Round the edit field value to the nearest integer
            roundedValue = round(app.PixelSizeThresholdEditField.Value);
            roundedValue = max(1, roundedValue);
            roundedValue = min(app.PixelSizeThresholdSlider.Limits(2), roundedValue);

            app.PixelSizeThresholdEditField.Value = roundedValue;
            app.PixelSizeThresholdSlider.Value = roundedValue;

            app.State.isProcessed = false;
            app.updateInterface();
        end

        % Callback for ImageThresholdSlider: updates the edit field value
        function ImageThresholdSliderValueChanged(app, ~)
            app.ImageThresholdEditField.Value = app.ImageThresholdSlider.Value;
            if app.States.useGlobalThreshold
                app.GlobalThreshold = app.ImageThresholdSlider.Value;
            else
                app.LocalThreshold = app.ImageThresholdSlider.Value;
            end
            % Rethreshold the images
            app.rethresholdImages();
        end

        % Callback for ImageThresholdEditField: updates the slider value
        function ImageThresholdEditFieldValueChanged(app, ~)
            app.ImageThresholdSlider.Value = app.ImageThresholdEditField.Value;
            if app.States.useGlobalThreshold
                app.GlobalThreshold = app.ImageThresholdEditField.Value;
            else
                app.LocalThreshold = app.ImageThresholdEditField.Value;
            end
            % Rethreshold the images
            app.rethresholdImages();
        end

        % Callback for UITable cell selection: enables/disables the Visualize button
        function UITableCellSelection(app, event)
            if isempty(event.Indices) || ~app.State.isProcessed
                app.VisualizeButton.Enable = 'off';
            else
                app.VisualizeButton.Enable = 'on';
            end

            app.updateInterface();
        end

        % Callback for VisualizeButton: calls pncVisualize if a row is selected
        function VisualizeButtonPushed(app, ~)
            % If no row is selected, show an alert
            if isempty(app.UITable.Selection)
                uialert(app.UIFigure, 'Please select an image to visualize.', 'No Selection');
            else
                % Retrieve selected row (for example, the first selected row)
                selectedRow = app.UITable.Selection(1,1);
                % data = app.UITable.Data;
                % selectedFilename = data{selectedRow, 1};
                app.visualizeImage(selectedRow);
            end
        end

        % Callback for ExportTableButton: exports the table to a CSV file
        function ExportTableButtonPushed(app, ~)
            % Get the table data
            data = app.UITable.Data;
            % Get the file name to save the table
            [file, path] = uiputfile('*.csv', 'Save Table As');
            if ischar(file) && ischar(path)
                % Write the table to a CSV file
                writetable(cell2table(data), fullfile(path, file));
            end
        end

        % Callback for SaveVisualizationsButton: saves the visualizations to a folder
        function SaveVisualizationsButtonPushed(app, ~)
            % Get the folder to save the visualizations
            % default folder saves to the same folder as the input images
            folder = uigetdir(app.ImageFolder, 'Save Visualizations To');
            if folder ~= 0
                % For each file, we draw a figure and save the figure
                for i_file = 1:size(app.UITable.Data, 1)
                    if ~isempty(app.UITable.Data{i_file, 1})
                        app.visualizeImage(i_file, folder);
                    end
                end
            end
        end

        % Helper functions to update interface
        function updateInterface(app, ~)
            % if there are any selected rows, change the Process button text
            if isempty(app.UITable.Selection)
                app.ProcessButton.Text = 'Process All';
            else
                app.ProcessButton.Text = 'Process';
            end

            % Enable/disable buttons based on the state
            if app.State.isLoaded && ~app.State.isProcessing
                app.SettingsPanel.Enable = 'on';
                app.UITable.Enable = 'on';
            else
                app.SettingsPanel.Enable = 'off';
                app.UITable.Enable = 'off';
            end

            if app.State.isProcessed
                app.ProcessButton.Enable = 'on';
                if isempty(app.UITable.Selection)
                    app.VisualizeButton.Enable = 'off';
                else
                    app.VisualizeButton.Enable = 'on';
                end
                app.ExportTableButton.Enable = 'on';
                app.SaveVisualizationsButton.Enable = 'on';
            else
                app.ProcessButton.Enable = 'on';
                app.VisualizeButton.Enable = 'off';
                app.ExportTableButton.Enable = 'off';
                app.SaveVisualizationsButton.Enable = 'off';
            end

            drawnow;
        end

        function updateTable(app, index)
            % Update the table with the results as they are processed
            if nargin < 2
                % then we update the entire table
                for i_file = 1:size(app.UITable.Data, 1)
                    app.updateTable(i_file);
                end
            else
                % update only the row specified by index
                app.UITable.Data{index, 2} = app.Results{index, 1}.n_positive;
                app.UITable.Data{index, 3} = app.Results{index, 1}.n_total;
                app.UITable.Data{index, 4} = sprintf('%.2f%%', app.Results{index, 1}.percentage);
            end
            drawnow;
        end
    end

    % Internal methods
    methods (Access = public) % public for testing
        function image = loadImages(app, filepath)
            % Read the ND2 file
            imdata = nd2read(filepath);

            % Extract the channels
            ch1 = squeeze(imdata(:,:,1,:));
            ch2 = squeeze(imdata(:,:,2,:));
            % Scale ch1 to 0-1 with double
            ch1_max = app.scaleImage(max(ch1,[],3));
            ch1 = app.scaleImage(ch1);
            % Average project of ch1, max project of ch2
            ch1_mean = mean(ch1,3);
            ch2_max = max(ch2,[],3);
            ch2_thresh = app.thresholdImage(ch2_max);

            image = struct('ch1_max', ch1_max, 'ch1_mean', ch1_mean, 'ch2_max', ch2_max, 'ch2_thresh', ch2_thresh);
        end
        
        function rethresholdImages(app, index)
            if nargin < 2
                % rethreshold all images
                for i_image = 1:size(app.UITable.Data, 1)
                    filename = app.UITable.Data{i_image, 1};
                    if ~isempty(filename)
                        images = app.Images{i_image};
                        ch2_max = images.ch2_max;
                        ch2_thresh = app.thresholdImage(ch2_max);
                        app.Images{i_image}.ch2_thresh = ch2_thresh;
                    end
                end
            else
                % rethreshold only the image specified by index
                filename = app.UITable.Data{index, 1};
                if ~isempty(filename)
                    images = app.Images{index};
                    ch2_max = images.ch2_max;
                    ch2_thresh = app.thresholdImage(ch2_max);
                    app.Images{index}.ch2_thresh = ch2_thresh;
                end
            end
        end

        function imdata = scaleImage(~, imdata)
            % scale imdata to 0-1
            imdata = double(imdata);
            imdata = (imdata - min(imdata(:))) / (max(imdata(:)) - min(imdata(:)));
            % convert to 8-bit
            imdata = uint8(imdata * 255);
        end

        function thresh_img = thresholdImage(app, img)
            if app.State.useGlobalThreshold
                % use global threshold
                median_value = median(img(:));
                min_value = min(img(:));
                thres = median_value + (median_value - min_value) * (3 + 0.01 * app.GlobalThreshold);
                thresh_img = img > thres;
            else
                thres = (100 - app.ImageThresholdEditField.Value) * 0.001;
                local_thresh = adaptthresh(img,thres,'NeighborhoodSize',21,'Statistic','gaussian');
                thresh_img = imbinarize(img, local_thresh);
            end
        end

        function masks = segmentImages(app, index, debug_on)
            if nargin < 3
                debug_on = false;
            end

            score_threshold = 0.7;
            min_nucleus_area = 5000;
            max_nucleus_area = 50000;

            images = app.Images{index};
            filename = app.UITable.Data{index, 1};
            ch1_max = images.ch1_max;

            % perform segmentation using segment anything, (debug_on = true means verbose)
            do_segmentation = true;

            segmentation_file = fullfile(app.SegmentationResultsFolder, sprintf('%s_segmentation.mat', filename(1:end-4)));

            if app.SaveSegmentationResultsCheckBox.Value && isfile(segmentation_file)
                % check if the segmentation file exists and if the parameters are the same
                segmentation_data = load(segmentation_file, 'masks', 'min_nucleus_area', 'max_nucleus_area', 'score_threshold');
                if isfield(segmentation_data, 'masks') && ...
                        isfield(segmentation_data, 'min_nucleus_area') && ...
                        isfield(segmentation_data, 'max_nucleus_area') && ...
                        isfield(segmentation_data, 'score_threshold') && ...
                        (segmentation_data.min_nucleus_area == min_nucleus_area) && ...
                        (segmentation_data.max_nucleus_area == max_nucleus_area) && ...
                        (segmentation_data.score_threshold == score_threshold)
                    masks = segmentation_data.masks;
                    clear segmentation_data;
                    do_segmentation = false;
                end
            end

            if do_segmentation
                masks = imsegsam(ch1_max,...
                    'MinObjectArea',min_nucleus_area, ...
                    'MaxObjectArea',max_nucleus_area, ...
                    'ScoreThreshold',score_threshold,...
                    'Verbose',debug_on);
                if app.SaveSegmentationResultsCheckBox.Value
                    save(segmentation_file, 'masks', 'min_nucleus_area', 'max_nucleus_area', 'score_threshold');
                end
            end
        end

        function [basicStats, fullStats] = analyzeImages(app, index)
            % positive threshold
            positive_threshold = app.PixelSizeThresholdEditField.Value;

            masks = app.Masks{index};
            images = app.Images{index};
            ch1_mean = images.ch1_mean;
            ch1_max = images.ch1_max;
            ch2_thresh = images.ch2_thresh;
            
            % get statistics of the mask sizes
            im_size = size(ch2_thresh);
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
                'NumberCh2PixelsPositive', 'BadMask'};
            mask_stats = array2table(zeros(length(sortidx),length(mask_stats_vars)), 'VariableNames', mask_stats_vars);

            mask_overall = zeros(im_size);
            mask_positive = zeros(im_size);
            mask_negative = zeros(im_size);
            mask_bad = zeros(im_size);

            n_positive = 0;
            n_negative = 0;
            n_bad = 0;

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
                mask_stats{jj, 'Smoothness'} = app.smoothness(mask_current,20);

                ch1_mean_mask = ch1_mean(masks.PixelIdxList{sortidx(ii)});
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
                if ~isempty(app.SVMModel)
                    % Extract features for SVM prediction
                    X = mask_stats{jj, app.SVMModel.features};
                    X = (X - app.SVMModel.mean) ./ app.SVMModel.std;
                    mask_stats{jj, 'BadMask'} = predict(app.SVMModel.model, X);
                
                    if mask_stats{jj, 'BadMask'} == 0
                        % If the mask is not predicted as bad, update the overall mask
                        mask_overall(masks.PixelIdxList{sortidx(ii)}) = jj;
                
                        if sum(mask_ch2) >= positive_threshold
                            % If the mask has enough positive pixels, mark it as positive
                            mask_positive(masks.PixelIdxList{sortidx(ii)}) = jj;
                            n_positive = n_positive + 1;
                        else
                            % Otherwise, mark it as negative
                            mask_negative(masks.PixelIdxList{sortidx(ii)}) = jj;
                            n_negative = n_negative + 1;
                        end
                    else
                        % If the mask is predicted as bad, update the bad mask
                        mask_bad(masks.PixelIdxList{sortidx(ii)}) = jj;
                        n_bad = n_bad + 1;
                    end
                else
                    % If not predicting bad masks, update the overall mask
                    mask_overall(masks.PixelIdxList{sortidx(ii)}) = jj;
                
                    if sum(mask_ch2) >= positive_threshold
                        % If the mask has enough positive pixels, mark it as positive
                        mask_positive(masks.PixelIdxList{sortidx(ii)}) = jj;
                        n_positive = n_positive + 1;
                    else
                        % Otherwise, mark it as negative
                        mask_negative(masks.PixelIdxList{sortidx(ii)}) = jj;
                        n_negative = n_negative + 1;
                    end
                end
                
                jj = jj + 1;
            end

            n_masks = jj - 1;
            n_total = n_positive + n_negative;
            mask_stats = mask_stats(1:n_masks,:);

            perc = n_positive / n_total * 100;
            basicStats.percentage = perc;
            basicStats.n_negative = n_negative;
            basicStats.n_positive = n_positive;
            basicStats.n_bad = n_bad;
            basicStats.n_total = n_total;
            basicStats.n_masks = n_masks;

            fullStats = mask_stats;

            app.Masks{index}.mask_positive = mask_positive;
            app.Masks{index}.mask_negative = mask_negative;
            app.Masks{index}.mask_bad = mask_bad;
            app.Masks{index}.mask_overall = mask_overall;
        end

        function processImage(app, index)
            % Process the image
            masks = app.segmentImages(index);
            app.Masks{index} = masks;

            [basicStats, fullStats] = app.analyzeImages(index);
            app.Results{index, 1} = basicStats;
            app.Results{index, 2} = fullStats;

            app.updateTable(index);
        end

        % helper functions
        function [ch1_mean, ch1_max, ch2_max] = readImages(app, filepath)
            % Read the ND2 file
            imdata = nd2read(filepath);

            % Extract the channels
            ch1 = squeeze(imdata(:,:,1,:));
            ch2 = squeeze(imdata(:,:,2,:));
            % Scale ch1 to 0-1 with double
            ch1_max = app.scaleImage(max(ch1,[],3));
            ch1 = app.scaleImage(ch1);
            % Average project of ch1, max project of ch2
            ch1_mean = mean(ch1,3);
            ch2_max = max(ch2,[],3);
        end

        function val = smoothness(~, mask, sigma)
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

        function visualizeImage(app, index, savepath)
            f1 = figure(1); clf(f1);
            f1.Position = [app.UIFigure.Position(1:2)+[app.UIFigure.Position(3)+10,0], 1200,900];
            f1.Name = 'PNC Visualization';
            tiledlayout(2,2, 'TileSpacing', 'compact', 'Padding', 'compact');

            cmap = lines;
            
            ch1_max = app.Images{index}.ch1_max;
            ch2_max = app.Images{index}.ch2_max;
            ch2_thresh = app.Images{index}.ch2_thresh;
            mask_positive = app.Masks{index}.mask_positive;
            mask_negative = app.Masks{index}.mask_negative;
            mask_bad = app.Masks{index}.mask_bad;
            mask_overall = app.Masks{index}.mask_overall;
            full_stats = app.Results{index, 2};
            basic_stats = app.Results{index, 1};
    
            nexttile;
            imshow(ch1_max,[]);
            title('DAPI Signal');
        
            nexttile;
            maskOverlay = labeloverlay(ch1_max, mask_overall,'colormap',cmap);
            imshow(maskOverlay,[]);
            % overlay the mask number
            hold on;
            for ii = 1:basic_stats.n_masks
                mask_coord = full_stats{ii, {'CentroidX', 'CentroidY'}};
                text(mask_coord(1), mask_coord(2), string(ii), 'Color', 'w', 'horizontalalignment', 'center', 'verticalalignment', 'middle');
            end
            title('Unique masks');
        
            nexttile;
            imshow(ch2_max,[]);
            title('PNC Signal');
        
            nexttile;
            % overlay the mask on ch2
            combined_mask = (mask_positive > 0)*2 + (mask_negative > 0)*1 + (mask_bad > 0)*3;
            combined_mask = min(combined_mask, 3); % make sure the mask is within 1-3
            im = ch2_thresh;
        
            maskOverlay = labeloverlay(+im, combined_mask, ...
                'colormap',[255, 153, 179; 179, 195, 255; 200, 200, 200]./255);
            imshow(maskOverlay,[]);
            hold on;
            for ii = 1:basic_stats.n_masks
                mask_coord = full_stats{ii, {'CentroidX', 'CentroidY'}};
                mask_data = full_stats{ii, {'NumberCh2PixelsPositive'}};
                text(mask_coord(1), mask_coord(2), sprintf('%d', mask_data), 'Color', 'w', 'horizontalalignment', 'center', 'verticalalignment', 'middle');
            end
            title(sprintf('Positive: %d / %d, %.1f%%', basic_stats.n_positive, basic_stats.n_total, basic_stats.n_positive/basic_stats.n_total*100));
            
            if nargin > 2
                saveas(f1, fullfile(savepath, sprintf('%s_visualization.png', app.UITable.Data{index, 1}(1:end-4))));
            end

        end

        function loadSVMModel(app)
            % Load the SVM model
            if isfile('svm_model.mat')
                load('svm_model.mat', 'svm_model', 'svm_features', 'svm_mean', 'svm_std');
                app.SVMModel = struct('model', svm_model, 'features', svm_features, 'mean', svm_mean, 'std', svm_std);
            else
                app.SVMModel = [];
                warn('SVM model not found. No bad mask prediction will be made.');
            end
        end
    end

    %% App creation and deletion
    methods (Access = public)

        % Construct app
        function app = pncCounter
            runningApp = getRunningApp(app);
            % addcommon to the path
            addpath(fullfile(pwd, '..', 'common'));
            addpath(fullfile(pwd, '..', 'common', 'bfmatlab'));

            % Check for running singleton app
            if isempty(runningApp)
                createComponents(app)
                registerApp(app, app.UIFigure)
            else
                figure(runningApp.UIFigure)
                app = runningApp;
            end
            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)
            delete(app.UIFigure)
        end
    end
end
