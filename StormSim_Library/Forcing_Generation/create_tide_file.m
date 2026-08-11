function [data_table] = create_tide_file(station, datum, start_date, outName)
% create_tide_file Downloads a Year's worth of tidal predictions from NOAA
% CO-OPS API. Stations location and data availability can be found  
% <a href="matlab: web('https://tidesandcurrents.noaa.gov/stations.html?type=Water+Levels')">here</a>.
%
% Inputs:
%       station: NOAA CO-OPS unique station identifier. Number string with
%                7 characters (i.e. '8638660').
%
%       datum: Preferred vertical datum. The fucntion supports 
%              Mean Sea Level ('MSL') & North American Vertical Datum 1988
%              ('NAVD').
%       
%       start_date: Start date for data download. Must be a datesring with  
%                   'yyyyMMdd' format. Time must be in the GMT 
%                   timezone. Data and product availability can be seen in
%                   the station's data inventory page.
%
%
%       outName: Output file name and location (.csv).
%
% Outputs:
%       Sdata: Downloaded tidal prediction dataset.
%
%       StationList: Requested station metadata.
%
%       tidal_file: Downloaded preedcition data is written to a CSV file
%       under outName.
%
% Example Usage:
%       data = create_tide_file('1617760', 'MSL', '1975-01-01 00:00:00', '1976-01-021 00:00:00', outName)

%% INPUTS 
% 1. Define your starting date
initial_stdate = datetime(start_date, 'InputFormat', 'yyyyMMdd');

% 2. Define the absolute final date for the year (1 year later, minus 1 day)
final_endate = initial_stdate + calyears(1) - caldays(1);

% 3. Generate start dates stepping by 31 days (column vector)
stdate = (initial_stdate : caldays(31) : final_endate)';

% 4. Generate end dates (start date + 30 days = 31 total days per pull)
endate = stdate + caldays(30);

% 5. Cap the final end date so it doesn't overshoot the 1-year mark
endate = min(endate, final_endate);

% 6. (Optional) Convert back to strings if your data API requires text inputs
stdate_str = string(stdate, 'yyyyMMdd');
endate_str = string(endate, 'yyyyMMdd');



opts = weboptions("Timeout",300);
data_table = [];
for kk = 1:length(endate_str)


    url_pth =['https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?begin_date='...
        char(stdate_str(kk)) '&end_date=' char(endate_str(kk)) '&station=' station '&product=predictions&datum=' datum '&time_zone=gmt&units=metric&format=csv'];
    data = webread(url_pth, opts);
    data_table = [data_table;data];
end

target_date = (initial_stdate : hours(1) : final_endate)';

hourly_tide = interp1(data_table.DateTime, data_table.Prediction, target_date);

data_table.Properties.VariableNames = {'Date','Prediction [m]'};

%% CREATE TIDAL FILE (MEANT FOR 1 STATION)
% Parse Tidal File
writetable(data_table,outName);
end