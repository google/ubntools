# ubntools

Copyright 2017 Google Inc.

This is not a google product.

Tools to do fun things with ubiquity gear.

## HOWTO

### 1. Log in to AP

### 2. Generate SSH key

```
$ dropbearkey -t rsa -f ~/.ssh/id_dropbear -s 2048
ssh-rsa AAAA…== admin@apname
```

### 3. Add this key to server's `~/.ssh/authorized_keys`

### 4. Set up regular data uploads

On the AP, run:
```
$ nohup sh -c 'while true; do ./ap-uploader.sh user@server:path/;sleep 600;done'
```

Make sure files are being uploaded to the server every 10 minutes. If it all
looks good then the AP setup is done. At least until it reboots.

### 5. On server: Create database

```
$ createdb ubntools
$ psql ubntools -f schema.sql
```

### 6. Import data

```
$ go build inserter.go
$ ./inserter -dbconnect='dbname=ubntools host=/var/run/postgresql sslmode=disable' /path/to/*.gz
```

### 7. Query data

```
$ psql ubntools
ubntools=> SELECT * FROM view_neighbors;
    ap    | channel |       bssid       |         essid          | bw | rssi | security | adhoc
----------+---------+-------------------+------------------------+----+------+----------+-------
  apname  |       6 | 00:8e:f2:aa:aa:aa | virginmediaxxxxxxx     | 20 |   10 | secured  | f
[…]
```

### 8. Generate channel utilization graph

```
$ go build mkgraph.go
$ ./mkgraph -dbconnect='dbname=ubntools host=/var/run/postgresql sslmode=disable' | gnuplot
$ mv foo.png /path/to/web/root/or/something/
```

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
