-- SQLite
-- airlines table
CREATE TABLE airlines (
    IATA_CODE TEXT PRIMARY KEY,
    AIRLINE_NAME TEXT
);

-- airports table
CREATE TABLE airports (
    IATA_CODE TEXT PRIMARY KEY,
    AIRPORT_NAME TEXT,
    CITY TEXT,
    STATE TEXT,
    COUNTRY TEXT,
    LATITUDE REAL,
    LONGITUDE REAL
);

-- flights table
CREATE TABLE flights (
    FLIGHT_ID INTEGER PRIMARY KEY AUTOINCREMENT,
    YEAR INTEGER,
    MONTH INTEGER,
    DAY INTEGER,
    DAY_OF_WEEK INTEGER,
    AIRLINE TEXT,
    FLIGHT_NUMBER TEXT,
    ORIGIN_AIRPORT TEXT,
    DESTINATION_AIRPORT TEXT,
    SCHEDULED_DEPARTURE INTEGER,
    DEPARTURE_TIME INTEGER,
    DEPARTURE_DELAY INTEGER,
    SCHEDULED_ARRIVAL INTEGER,
    ARRIVAL_TIME INTEGER,
    ARRIVAL_DELAY INTEGER,
    CANCELLED INTEGER,
    CANCELLATION_REASON TEXT,
    AIR_SYSTEM_DELAY INTEGER,
    SECURITY_DELAY INTEGER,
    AIRLINE_DELAY INTEGER,
    LATE_AIRCRAFT_DELAY INTEGER,
    WEATHER_DELAY INTEGER,
    DISTANCE INTEGER
);


SELECT COUNT(*) FROM flights;
SELECT * FROM flights LIMIT 5;

--DATA CLEANING
--TIME/DATE HANDLING (Create proper datetime)

ALTER TABLE flights ADD COLUMN FLIGHT_DATE TEXT;

UPDATE flights
SET FLIGHT_DATE = 
    printf('%04d-%02d-%02d', YEAR, MONTH, DAY);

--Create SCHEDULED_DATETIME (hour + minute from HHMM format)

ALTER TABLE flights ADD COLUMN SCHEDULED_DATETIME TEXT;

UPDATE flights
SET SCHEDULED_DATETIME = 
    printf('%04d-%02d-%02d %02d:%02d', 
        YEAR, MONTH, DAY, 
        SCHEDULED_DEPARTURE / 100, 
        SCHEDULED_DEPARTURE % 100
    );


-- MISSING VALUES HANDLING

SELECT COUNT(*) AS null_departure_delay 
FROM flights WHERE DEPARTURE_DELAY IS NULL;

SELECT COUNT(*) AS null_cancellation 
FROM flights WHERE CANCELLED = 1 AND CANCELLATION_REASON IS NULL;


UPDATE flights
SET DEPARTURE_DELAY = 0
WHERE DEPARTURE_DELAY IS NULL;

UPDATE flights
SET ARRIVAL_DELAY = 0
WHERE ARRIVAL_DELAY IS NULL;

--DATA ENRICHMENT – CANCELLATION REASON DESCRIPTION

ALTER TABLE flights ADD COLUMN CANCELLATION_REASON_DESC TEXT;

UPDATE flights
SET CANCELLATION_REASON_DESC =
    CASE CANCELLATION_REASON
        WHEN 'A' THEN 'Airline/Carrier'
        WHEN 'B' THEN 'Weather'
        WHEN 'C' THEN 'National Air System (NAS)'
        WHEN 'D' THEN 'Security'
        ELSE 'Not Cancelled'
    END;


-- DATA INTEGRATION – JOIN TABLES

CREATE VIEW flight_analysis_view AS
SELECT 
    f.*,
    a.AIRLINE,
    ao.AIRPORT AS ORIGIN_AIRPORT_NAME,
    ao.CITY AS ORIGIN_CITY,
    ad.AIRPORT AS DESTINATION_AIRPORT_NAME,
    ad.CITY AS DESTINATION_CITY
FROM flights f
JOIN airlines a ON f.AIRLINE = a.IATA_CODE
JOIN airports ao ON f.ORIGIN_AIRPORT = ao.IATA_CODE
JOIN airports ad ON f.DESTINATION_AIRPORT = ad.IATA_CODE;

SELECT * FROM flight_analysis_view LIMIT 5;


----------------------PHASE-3:EDA & KPI DEFINITION----------------------------------------------

--------Basic Flight Stats

--Total Flights
SELECT COUNT(*) AS total_flights FROM flight_analysis_view;

-- Total Cancelled Flights
SELECT COUNT(*) AS cancelled_flights
FROM flight_analysis_view
WHERE CANCELLED = 1;

--Cancellation Rate (%)
SELECT 
  ROUND(CAST(SUM(CANCELLED) AS FLOAT) * 100 / COUNT(*), 2) AS cancellation_rate_pct
FROM flight_analysis_view;


-------Delay Statistics
--Avg, Min, Max Delay (Arrival & Departure)

SELECT
  ROUND(AVG(ARRIVAL_DELAY), 2) AS avg_arrival_delay,
  MIN(ARRIVAL_DELAY) AS min_arrival_delay,
  MAX(ARRIVAL_DELAY) AS max_arrival_delay,
  ROUND(AVG(DEPARTURE_DELAY), 2) AS avg_departure_delay,
  MIN(DEPARTURE_DELAY) AS min_departure_delay,
  MAX(DEPARTURE_DELAY) AS max_departure_delay
FROM flight_analysis_view
WHERE CANCELLED = 0;


-------On-Time Performance (OTP)
---Arrival delay ≤ 15 minutes
SELECT
  ROUND(SUM(CASE WHEN ARRIVAL_DELAY <= 15 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS on_time_arrival_rate_pct
FROM flight_analysis_view
WHERE CANCELLED = 0;

-----Delay Type Contribution
---Shows which delay type causes the most issues:

SELECT
  ROUND(SUM(AIR_SYSTEM_DELAY) * 1.0 / SUM(ARRIVAL_DELAY) * 100, 2) AS air_system_pct,
  ROUND(SUM(SECURITY_DELAY) * 1.0 / SUM(ARRIVAL_DELAY) * 100, 2) AS security_pct,
  ROUND(SUM(AIRLINE_DELAY) * 1.0 / SUM(ARRIVAL_DELAY) * 100, 2) AS airline_pct,
  ROUND(SUM(LATE_AIRCRAFT_DELAY) * 1.0 / SUM(ARRIVAL_DELAY) * 100, 2) AS late_aircraft_pct,
  ROUND(SUM(WEATHER_DELAY) * 1.0 / SUM(ARRIVAL_DELAY) * 100, 2) AS weather_pct
FROM flight_analysis_view
WHERE CANCELLED = 0;


------- Grouping by Airline
-- Avg Delay by Airline

SELECT 
  AIRLINE,
  ROUND(AVG(ARRIVAL_DELAY), 2) AS avg_arrival_delay,
  ROUND(AVG(DEPARTURE_DELAY), 2) AS avg_departure_delay,
  COUNT(*) AS total_flights
FROM flight_analysis_view
GROUP BY AIRLINE
ORDER BY avg_arrival_delay DESC;


----Grouping by Airport, Day, or Hour
--Delay by Origin Airport

SELECT 
  ORIGIN_AIRPORT_NAME,
  ROUND(AVG(ARRIVAL_DELAY), 2) AS avg_arrival_delay
FROM flight_analysis_view
GROUP BY ORIGIN_AIRPORT_NAME
ORDER BY avg_arrival_delay DESC
LIMIT 10;


-- Delay by Day of Week
SELECT 
  DAY_OF_WEEK,
  ROUND(AVG(ARRIVAL_DELAY), 2) AS avg_arrival_delay
FROM flight_analysis_view
GROUP BY DAY_OF_WEEK
ORDER BY DAY_OF_WEEK;


SELECT * FROM flight_analysis_view;
