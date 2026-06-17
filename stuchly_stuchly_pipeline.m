%% Stuchly and Stuchly Permittivity Extraction from S11 CSV Files
% This script implements a three-standard Stuchly and Stuchly conversion
% algorithm for extracting complex permittivity from VNA S11 measurements.
%
% Folder structure:
%
%   Reference data/
%       reference 1.csv
%       reference 2.csv
%       reference 3.csv
%       validation solution.csv
%
%   Measurements/
%       ref 1 m1.csv
%       ref 1 m2.csv
%       ref 1 m3.csv
%       ref 2 m1.csv
%       ...
%       s1 m1.csv
%       s1 m2.csv
%       s1 m3.csv
%       ...
%       validation m1.csv
%       validation m2.csv
%       validation m3.csv
%
%   Results/
%
% Measurement CSV format:
%   frequency_Hz, real(S11), imag(S11)
%
% Reference-permittivity CSV format:
%   frequency_Hz, epsilon_real, epsilon_imag

clear variables
close all
clc

addpath("functions");

%% USER SETTINGS

dataFolder = "example_data";
referenceFolder = fullfile(dataFolder, "Reference data");
measurementFolder = fullfile(dataFolder, "Measurements");
resultsFolder = fullfile("Results");

if ~exist(resultsFolder, "dir")
    mkdir(resultsFolder);
end

% Three calibration standards used by the Stuchly and Stuchly algorithm.
standardIds = ["ref 1", "ref 2", "ref 3"];
referencePermittivityFiles = ["reference 1.csv", "reference 2.csv", "reference 3.csv"];

% Materials under test. Each material must have m1, m2, and m3 CSV files.
materialIds = ["s1", "s2", "s3"];
materialLabels = ["Sample 1", "Sample 2", "Sample 3"];

% Optional validation measurement groups. Examples:
%   validationMeasurementIds = ["validation"];
%   validationMeasurementIds = ["validation start", "validation end"];
%
% The code searches for 3 repeated validation measurements per group
% format: <validationMeasurementId> m1.csv
%
% If multiple validation groups are provided, each group is first averaged
% over m1/m2/m3, then all validation groups are averaged together before
% comparison with the reference validation solution.
validationMeasurementIds = ["validation start", "validation end"];
validationReferenceFile = "validation solution.csv";

repeatLabels = ["m1", "m2", "m3"];

% Plot settings
uncertaintyMaterialIndices = [1, 3]; % Use [] to hide all uncertainty regions.
plotMaterialIndices = 1:numel(materialIds);
frequencyLimitsGHz = [0.5, 4.5];
smoothingEnabled = true;
sgolayWindow = 30;

% VNA drift uncertainty component (%).
driftPercent = 0.1 / sqrt(3);

%% LOAD CALIBRATION STANDARD S11 MEASUREMENTS

numStandards = numel(standardIds);
standardS11 = cell(1, numStandards);

for i = 1:numStandards
    [freqHz, standardRepeats] = read_repeated_s11( ...
        measurementFolder, standardIds(i), repeatLabels);

    standardS11{i} = mean(standardRepeats, 2);
end

%% LOAD REFERENCE PERMITTIVITY DATA

referencePermittivity = cell(1, numStandards);

for i = 1:numStandards
    referenceFile = fullfile(referenceFolder, referencePermittivityFiles(i));
    [freqReferenceHz, epsReal, epsImag] = read_reference_permittivity(referenceFile);

    check_frequency_axis(freqHz, freqReferenceHz, referenceFile);

    % Conjugation follows the convention used in the original implementation.
    referencePermittivity{i} = conj(complex(epsReal, epsImag));
end

%% LOAD MATERIAL MEASUREMENTS AND APPLY STUCHLY-STUCHLY CONVERSION

numMaterials = numel(materialIds);

epsilonAverage = cell(1, numMaterials);
epsilonRepeats = cell(1, numMaterials);

epsilonReal = cell(1, numMaterials);
epsilonImag = cell(1, numMaterials);
epsilonRealStd = cell(1, numMaterials);
epsilonImagStd = cell(1, numMaterials);

for i = 1:numMaterials
    [freqMaterialHz, materialRepeats] = read_repeated_s11( ...
        measurementFolder, materialIds(i), repeatLabels);

    check_frequency_axis(freqHz, freqMaterialHz, materialIds(i));

    materialAverage = mean(materialRepeats, 2);

    epsilonAverage{i} = stuchly_stuchly_conversion( ...
        materialAverage, standardS11, referencePermittivity);

    for repeatIndex = 1:numel(repeatLabels)
        epsilonRepeats{i}(:, repeatIndex) = stuchly_stuchly_conversion( ...
            materialRepeats(:, repeatIndex), standardS11, referencePermittivity);
    end

    epsilonReal{i} = real(epsilonAverage{i});
    epsilonImag{i} = imag(epsilonAverage{i});

    epsilonRealStd{i} = std(real(epsilonRepeats{i}), 0, 2);
    epsilonImagStd{i} = std(imag(epsilonRepeats{i}), 0, 2);
end

%% OPTIONAL VALIDATION MEASUREMENTS FOR REFERENCE UNCERTAINTY

referenceUncertaintyRealPercent = zeros(size(freqHz));
referenceUncertaintyImagPercent = zeros(size(freqHz));

if ~isempty(validationMeasurementIds)
    validationEpsilon = zeros(numel(freqHz), numel(validationMeasurementIds));

    for validationIndex = 1:numel(validationMeasurementIds)
        [freqValidationHz, validationRepeats] = read_repeated_s11( ...
            measurementFolder, validationMeasurementIds(validationIndex), repeatLabels);

        check_frequency_axis( ...
            freqHz, freqValidationHz, validationMeasurementIds(validationIndex));

        validationAverageS11 = mean(validationRepeats, 2);

        validationEpsilon(:, validationIndex) = stuchly_stuchly_conversion( ...
            validationAverageS11, standardS11, referencePermittivity);
    end

    % If multiple validation groups are provided, average them.
    % If only one is provided, this is simply the single validation spectrum.
    validationEpsilonAverage = mean(validationEpsilon, 2);

    validationReferencePath = fullfile(referenceFolder, validationReferenceFile);
    [freqValidationRefHz, validationRealRef, validationImagRef] = ...
        read_reference_permittivity(validationReferencePath);

    check_frequency_axis(freqHz, freqValidationRefHz, validationReferencePath);

    validationRealMeasured = real(validationEpsilonAverage);
    validationImagMeasured = imag(validationEpsilonAverage);

    referenceUncertaintyRealPercent = abs( ...
        (validationRealRef - validationRealMeasured) ./ validationRealRef ...
    ) * 100 / sqrt(3);

    referenceUncertaintyImagPercent = abs( ...
        (validationImagRef - validationImagMeasured) ./ validationImagRef ...
    ) * 100 / sqrt(3);
end

%% UNCERTAINTY ESTIMATION

realUncertainty = cell(1, numMaterials);
imagUncertainty = cell(1, numMaterials);

for i = 1:numMaterials
    repeatabilityRealPercent = abs(epsilonRealStd{i} ./ epsilonReal{i}) * 100;
    repeatabilityImagPercent = abs(epsilonImagStd{i} ./ epsilonImag{i}) * 100;

    totalRealPercent = sqrt( ...
        repeatabilityRealPercent.^2 + ...
        referenceUncertaintyRealPercent.^2 + ...
        driftPercent.^2);

    totalImagPercent = sqrt( ...
        repeatabilityImagPercent.^2 + ...
        referenceUncertaintyImagPercent.^2 + ...
        driftPercent.^2);

    realUncertainty{i} = abs(totalRealPercent .* epsilonReal{i} / 100);
    imagUncertainty{i} = abs(totalImagPercent .* epsilonImag{i} / 100);
end

%% OPTIONAL SMOOTHING FOR VISUALISATION

if smoothingEnabled
    for i = 1:numMaterials
        epsilonReal{i} = smoothdata(epsilonReal{i}, "sgolay", sgolayWindow);
        epsilonImag{i} = smoothdata(epsilonImag{i}, "sgolay", sgolayWindow);
    end
end

%% EXPORT RESULTS

for i = 1:numMaterials
    outputTable = table( ...
        freqHz, ...
        epsilonReal{i}, ...
        epsilonImag{i}, ...
        realUncertainty{i}, ...
        imagUncertainty{i}, ...
        'VariableNames', { ...
            'Frequency_Hz', ...
            'Epsilon_Real', ...
            'Epsilon_Imag', ...
            'Real_Uncertainty', ...
            'Imag_Uncertainty' ...
        } ...
    );

    writetable(outputTable, fullfile(resultsFolder, materialIds(i) + "_permittivity.csv"));
end

%% PLOT RESULTS
colorOrder = colororder;

freqGHz = freqHz / 1e9;

figure;
hold on

for i = plotMaterialIndices
    plot(freqGHz, epsilonReal{i}, "LineWidth", 1.2);
end

for i = uncertaintyMaterialIndices
    colorIndex = mod(find(plotMaterialIndices == i) - 1, size(colorOrder, 1)) + 1;
    shadeColor = colorOrder(colorIndex, :);

    x = freqGHz(:)';
    y = epsilonReal{i}(:)';
    u = realUncertainty{i}(:)';

    fill([x, fliplr(x)], ...
         [y + u, fliplr(y - u)], ...
         shadeColor, ...
         "FaceAlpha", 0.12, ...
         "EdgeColor", "none", ...
         "HandleVisibility", "off");
end

xlabel("Frequency (GHz)")
ylabel("\epsilon'")
title("Extracted Real Relative Permittivity")
legend(materialLabels(plotMaterialIndices), "Location", "best")
xlim(frequencyLimitsGHz)
grid on
grid minor
hold off

saveas(gcf, fullfile(resultsFolder, "real_permittivity.png"));
saveas(gcf, fullfile(resultsFolder, "real_permittivity.fig"));

figure;
hold on

for i = plotMaterialIndices
    plot(freqGHz, epsilonImag{i}, "LineWidth", 1.2);
end

for i = uncertaintyMaterialIndices
    colorIndex = mod(find(plotMaterialIndices == i) - 1, size(colorOrder, 1)) + 1;
    shadeColor = colorOrder(colorIndex, :);

    x = freqGHz(:)';
    y = epsilonImag{i}(:)';
    u = imagUncertainty{i}(:)';

    fill([x, fliplr(x)], ...
         [y + u, fliplr(y - u)], ...
         shadeColor, ...
         "FaceAlpha", 0.12, ...
         "EdgeColor", "none", ...
         "HandleVisibility", "off");
end

xlabel("Frequency (GHz)")
ylabel("\epsilon''")
title("Extracted Loss Factor")
legend(materialLabels(plotMaterialIndices), "Location", "best")
xlim(frequencyLimitsGHz)
grid on
grid minor
hold off

saveas(gcf, fullfile(resultsFolder, "imaginary_permittivity.png"));
saveas(gcf, fullfile(resultsFolder, "imaginary_permittivity.fig"));

%% LOCAL FUNCTIONS

function [freqHz, s11Repeats] = read_repeated_s11(folder, sampleId, repeatLabels)
    numRepeats = numel(repeatLabels);
    s11Repeats = [];

    for repeatIndex = 1:numRepeats
        fileName = sampleId + " " + repeatLabels(repeatIndex) + ".csv";
        filePath = fullfile(folder, fileName);

        [freqCurrentHz, s11Current] = read_s11_csv(filePath);

        if repeatIndex == 1
            freqHz = freqCurrentHz;
            s11Repeats = zeros(numel(freqHz), numRepeats);
        else
            check_frequency_axis(freqHz, freqCurrentHz, filePath);
        end

        s11Repeats(:, repeatIndex) = s11Current;
    end
end


function [freqHz, s11] = read_s11_csv(filePath)
    if ~isfile(filePath)
        error("File not found: %s", filePath);
    end

    rawData = readmatrix(filePath, "NumHeaderLines", 3);

    freqHz = rawData(:, 1);
    s11Real = rawData(:, 2);
    s11Imag = rawData(:, 3);

    s11 = complex(s11Real, s11Imag);
end


function [freqHz, epsReal, epsImag] = read_reference_permittivity(filePath)
    if ~isfile(filePath)
        error("File not found: %s", filePath);
    end

    rawData = readmatrix(filePath, "NumHeaderLines", 2);

    freqHz = rawData(:, 1);
    epsReal = rawData(:, 2);
    epsImag = rawData(:, 3);
end


function epsilon = stuchly_stuchly_conversion(materialS11, standardS11, referencePermittivity)
    p1 = standardS11{1};
    p2 = standardS11{2};
    p3 = standardS11{3};

    e1 = referencePermittivity{1};
    e2 = referencePermittivity{2};
    e3 = referencePermittivity{3};

    d13 = p1 - p3;
    d21 = p2 - p1;
    d32 = p3 - p2;

    dm1 = materialS11 - p1;
    dm2 = materialS11 - p2;
    dm3 = materialS11 - p3;

    epsilon = -(( ...
        dm1 .* d32 .* e3 .* e2 + ...
        dm2 .* d13 .* e1 .* e3 + ...
        dm3 .* d21 .* e2 .* e1) ./ ...
        (dm1 .* d32 .* e1 + ...
        dm2 .* d13 .* e2 + ...
        dm3 .* d21 .* e3));

    epsilon = conj(epsilon);
end


function check_frequency_axis(referenceFrequencyHz, currentFrequencyHz, fileName)
    if numel(referenceFrequencyHz) ~= numel(currentFrequencyHz) || ...
       any(abs(referenceFrequencyHz - currentFrequencyHz) > 1e-6)
        error("Frequency axis mismatch in file: %s", string(fileName));
    end
end
