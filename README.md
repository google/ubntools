## Interesting queries



### Current clients
```
SELECT
  essid,
  ap,
  channel,
  data->>'hostname' hostname,
  data->>'mac' mac,
  data->>'rssi' rssi
FROM sta_table_latest
ORDER BY essid,ap,channel,hostname,mac;
```

### Active radios
```
SELECT
  ap,
  data->>'name' AS name,
  data->>'radio' AS radio,
  CASE data->>'is_11ac' WHEN 'true' THEN TRUE ELSE FALSE END as "802.11ac",
  data->>'max_txpower' AS power
FROM radio_table_latest
ORDER BY ap, name;
```

### One client's RSSI over time
```
SELECT
  ts,
  (data->>'rssi')::int rssi
FROM sta_table
WHERE data->>'mac'='11:22:33:44:55:66'
ORDER BY ts;
```

### rssi of clients over time
```
SELECT
  ap,
  ts,
  essid,
  channel,
  data->>'hostname' hostname,
  data->>'mac' mac,
  data->>'rssi' rssi
FROM sta_table
ORDER BY data->>'mac',ts;
```
