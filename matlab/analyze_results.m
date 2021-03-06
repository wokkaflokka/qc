%% read all qugrs
shape = 'qugrs'
name = [shape '_all'];
stats=[dlmread('../results/old/qugrs_all_counts.txt')];

%% read all qust
shape = 'qust'
name = [shape '_all'];
stats=dlmread('../results/old/qust_all_counts.txt');
%% read single stats file
shape = 'qust';
name = [shape '_700_to_900'];
filename = ['../results/old/' name '_counts.txt'];
%filename = '../c/qugrs_1000.1_counts.txt';
stats = dlmread(filename);
%%
ks = stats(:,1);
counts = stats(:,2);

% constants
alpha = 0.7;
fontsize = 20;

% qugrs shape
if strcmp(shape, 'qugrs')
    a = 1;
    t1=.4;
    t2=.7;
    R1 = a/sin(t1);
    R2=1/sin(t2);
    area = a - R1^2*(2*t1 - sin(2*t1))/4 - R2^2*(2*t2 - sin(2*t2))/4;

% qust shape
elseif strcmp(shape, 'qust')
    area = 1 + pi / 4;

% percolation grid
elseif strcmp(shape, 'perc') || strcmp(shape, 'rpw')
    area = 1;

else error(['invalid shape: ' shape]);
end

%% compute mean
mean_predicted = (3*sqrt(3) - 5)/pi;

means = [];
k_windows = [];
scaled_counts = 4*pi*counts./(area*ks.^2);


%ws = 1000; %window size
%for i=1:ws:length(counts)
%    idx = i:min(i+ws,length(counts));
%    k = ks(min(i+ws/2,length(ks)));
%    k_windows = [k_windows k];
%    means = [means mean(scaled_counts(idx))];
%end

k_jumps = [ks((diff(ks) > 5)) ; ks(numel(ks))]';
k_width = 3;

for k=k_jumps
    idx = (ks > k - k_width) & (ks <= k);
    k_windows = [k_windows mean(ks(idx))];
    means = [means mean(scaled_counts(idx))];
end

mean_error = abs(mean(means) - mean_predicted) / mean_predicted;

figure;
plot(ks, scaled_counts, '.');
hold on;
plot(k_windows, means, 'k-', 'LineWidth', 3);
plot([min(ks), max(ks)], [mean_predicted, mean_predicted], 'r-', 'LineWidth', 3);

% fit A + B/sqrt(N)
%p = polyfit(1./ks, scaled_counts, 1); % theory is [~.5348 .0624]
[coeffs,stderrp] = lscov(x2fx(1./ks), scaled_counts); % same as above but also gives std errors (and p is reversed)
df = numel(ks) - 1; % degrees of freedom

plot(ks, polyval(flipud(coeffs), 1./ks), 'g');

t = (coeffs(1) - mean_predicted) / (stderrp(1) / sqrt(df)); % t statistic of intercept
p = 1 - 2 * tcdf(-abs(t), df)

    
xlabel('k', 'FontSize', fontsize);
ylabel('\nu(k)/N(k)', 'FontSize', fontsize);
legend('data', 'measured mean', 'predicted mean', sprintf('%.4f + %.4f/k', coeffs(1), coeffs(2)));
set(gca, 'FontSize', fontsize);
print('-deps2c', ['../documents/thesis/figs/results/' name '_old_mean.eps']);

%% compute variance
variance_predicted = 18/pi^2 + 4*sqrt(3)/pi - 25/(2*pi);

scaled_counts = sqrt(4*pi./(area.*ks.^2)).*counts;

vars = [];
k_windows = [];

ws = 100; %window size
for i=1:ws:length(counts)
    idx = i:min(i+ws,length(counts));
    k = ks(min(i+ws/2,length(ks)));
    k_windows = [k_windows k];
    vars = [vars var(scaled_counts(idx))];
end

%k_jumps = [ks((diff(ks) > 5)) ; ks(numel(ks))]';
%k_width = 3;

%for k=k_jumps
%    idx = (ks > k - k_width) & (ks <= k);
%    k_windows = [k_windows mean(ks(idx))];
%    vars = [vars var(scaled_counts(idx))];
%end

figure;
plot(k_windows, vars, 'k-', 'LineWidth', 3);
hold on;
plot([min(ks), max(ks)], [variance_predicted, variance_predicted], 'r-', 'LineWidth', 3);
xlabel('k', 'FontSize', fontsize);
ylabel('\sigma^{2}(k)/N(k)', 'FontSize', fontsize);
legend('measured variance', 'predicted variance');
set(gca, 'FontSize', fontsize);
print('-deps2c', ['../documents/thesis/figs/results/' name '_variance.eps']);

%% check interp counts
interp_counts = stats(:,4);

% interpolations per domain
figure; plot(interp_counts./counts);

%%
% interpolations per pixel
dxs = alpha ./ ks;
pixels = area ./ dxs.^2;
figure; plot(ks, interp_counts./pixels, '.');
hold on;
m = mean(interp_counts./pixels)
%%
plot([min(ks), max(ks)], [m, m], 'r-', 'LineWidth', 3);
xlabel('k', 'FontSize', fontsize);
ylabel('interpolations per pixel', 'FontSize', fontsize);
legend('data', 'mean'); 
set(gca, 'FontSize', fontsize);
%print('-deps2c', '../documents/thesis/figs/results/interp_counts.eps');

%% check wtms
wtms = stats(:,7);
figure;
plot(wtms, scaled_counts, '.');
xlabel('wing tip mass', 'FontSize', fontsize);
ylabel('\nu(k)/N(k)', 'FontSize', fontsize);
set(gca, 'FontSize', fontsize);
print('-deps2c', ['../documents/thesis/figs/results/' name '_wtms.eps']);

%% check distribution
figure;
hist(scaled_counts ,1000);
xlabel('k', 'FontSize', fontsize);
set(gca, 'YTickLabel', []);
set(gca, 'FontSize', fontsize);
print('-deps2c', ['../documents/thesis/figs/results/' name '_count_histogram.eps']);
