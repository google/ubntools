CREATE EXTENSION pgcrypto;
CREATE TABLE apdata(
       id UUID NOT NULL,
       ts TIMESTAMP WITH TIME ZONE NOT NULL,
       data JSONB NOT NULL,
       PRIMARY KEY(id)
);
-- TODO: create index on serial and ts?

-- Prevent duplicate insertions.
CREATE UNIQUE INDEX apdata_unique_idx ON apdata(((data->>'mac')::text), ((data->>'time')::text));

CREATE VIEW apdata_latest AS
SELECT
  data->>'hostname' AS ap,
  apdata.ts,
  apdata.data
FROM apdata
JOIN (
  SELECT
    data->>'serial' AS serial,
    MAX(ts) AS ts
  FROM apdata
  GROUP BY serial
) AS rhs
ON rhs.serial=apdata.data->>'serial'
AND rhs.ts=apdata.ts;

-- Radio hardware.
CREATE VIEW radio_table AS
SELECT
  data->>'hostname' AS ap,
  ts,
  jsonb_array_elements(data->'radio_table') AS data
FROM apdata;

CREATE VIEW radio_table_latest AS
SELECT
  ap,
  ts,
  jsonb_array_elements(data->'radio_table') AS data
FROM apdata_latest;

-- Neighbors.
CREATE VIEW scan_table AS
SELECT
  ap,
  ts,
  jsonb_array_elements(data->'scan_table') AS data
FROM radio_table;

CREATE VIEW scan_table_latest AS
SELECT
  ap,
  ts,
  jsonb_array_elements(data->'scan_table') AS data
FROM radio_table_latest;

-- Networks.
CREATE OR REPLACE VIEW vap_table AS
SELECT a.ap,
       a.ts,
       a.data
FROM (
  SELECT data->>'hostname' AS ap,
         ts,
         jsonb_array_elements(data->'vap_table') AS data
  FROM apdata
) a
WHERE (a.data ->> 'usage'::text) = 'user'::text;

CREATE OR REPLACE VIEW vap_table_latest AS
SELECT a.ap,
       a.ts,
       a.data
FROM (
  SELECT ap,
         ts,
         jsonb_array_elements(data->'vap_table') AS data
  FROM apdata_latest
) a
WHERE (a.data ->> 'usage'::text) = 'user'::text;

-- Connected clients.
CREATE VIEW sta_table AS
SELECT ap,
       ts,
       data ->> 'essid'::text AS essid,
       (data ->> 'channel')::int AS channel,
       jsonb_array_elements(data->'sta_table') AS data
FROM vap_table;

CREATE VIEW sta_table_latest AS
SELECT ap,
       ts,
       data ->> 'essid'::text AS essid,
       (data ->> 'channel')::int AS channel,
       jsonb_array_elements(data->'sta_table') AS data
FROM vap_table_latest;

-- Pretty user-friendly queries.
CREATE VIEW view_clients AS SELECT
  essid,
  ap,
  channel,
  data->>'hostname' AS hostname,
  data->>'mac' AS mac,
  (data->>'ip')::inet AS ip,
  (data->>'rssi')::int AS rssi,
  (data->>'signal')::int AS signal,
  (data->>'rx_rate')::int8/1000 AS downlink,  -- I think this is not backwards.
  (data->>'tx_rate')::int8/1000 AS uplink,
  (data->>'rx_bytes')::int8+(data->>'tx_bytes')::int8 AS byte_counter
FROM sta_table_latest
ORDER BY essid,ap,channel,hostname,mac;

CREATE VIEW view_clients_history AS SELECT
  ts,
  essid,
  ap,
  channel,
  data->>'hostname' AS hostname,
  data->>'mac' AS mac,
  (data->>'ip')::inet AS ip,
  (data->>'rssi')::int AS rssi,
  (data->>'signal')::int AS signal,
  (data->>'rx_rate')::int8/1000 AS downlink,  -- I think this is not backwards.
  (data->>'tx_rate')::int8/1000 AS uplink,
  (data->>'rx_bytes')::int8+(data->>'tx_bytes')::int8 AS byte_counter
FROM sta_table
ORDER BY essid,ap,channel,hostname,mac;

CREATE VIEW view_networks AS
SELECT
  ap,
  data->>'channel' AS channel,
  data->>'essid' AS essid,
  (data->>'rx_bytes')::int8+(data->>'tx_bytes')::int8 AS byte_counter
FROM vap_table_latest
ORDER BY ap,channel,essid;

CREATE VIEW view_radio AS
SELECT
  ap,
  data->>'name' AS name,
  (data#>>'{athstats,cu_total}')::int AS cu,
  (data->>'max_txpower')::int AS max_tx,
  (data->>'min_txpower')::int as min_tx,
  data->>'radio' AS radio,
  CASE data->>'is_11ac' WHEN 'true' THEN TRUE ELSE FALSE END AS ac,
  CASE data->>'has_dfs' WHEN 'true' THEN TRUE ELSE FALSE END AS dfs,
  jsonb_array_length(data->'scan_table') AS ssid_count
FROM radio_table_latest;

CREATE VIEW view_neighbors AS
SELECT
  ap,
  (data->>'channel')::int AS channel,
  data->>'bssid' AS bssid,
  data->>'essid' AS essid,
  (data->>'bw')::int AS bw,
  (data->>'rssi')::int AS rssi,
  data->>'security' AS security,
  CASE data->>'is_adhoc' WHEN 'true' THEN TRUE ELSE FALSE END AS adhoc
FROM scan_table_latest
ORDER BY ap,channel,bssid,essid;
