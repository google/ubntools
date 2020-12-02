# ubntools

Copyright 2017 Google Inc.

This is not a google product.

Tools to do fun things with ubiquity gear.

## HOWTO

### 1. Log in to AP

### 2. Generate SSH key

```
$ mkdir ~/.ssh
$ dropbearkey -t rsa -f ~/.ssh/id_dropbear -s 2048
ssh-rsa AAAA…== admin@apname
```

### 3. Add this key to server's `~/.ssh/authorized_keys`

Try a one-time upload by uploading `ap-uploader.sh` to the AP and running:
```
$ ./ap-uploader.sh user@server:path/
```

### 4. Set up regular data uploads

On the AP, run:
```
$ nohup sh -c 'while true; do ./ap-uploader.sh user@server:path/;sleep 600;done' &
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

There are premade views (do `\d` and then `SELECT * from view_…`),
but you can query more raw data too.

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

### Show days when there was at least one DFS event forcing a change of channel

```
# SELECT TO_CHAR(ts,'YYYY-MM-DD') dayy,MIN(channel) channel FROM view_clients_history WHERE ap='ap-longrange' AND ts>'2020-11-01' AND channel>11 GROUP BY dayy ORDER BY dayy;
    dayy    | channel 
------------+---------
 2020-11-01 |     128
 2020-11-02 |     128
 2020-11-03 |     128
 2020-11-04 |     128
 2020-11-05 |     128
 2020-11-06 |      40
 2020-11-07 |      40
 2020-11-08 |      44
 2020-11-09 |     128
 2020-11-10 |     128
 2020-11-11 |      44
 2020-11-12 |      44
 2020-11-13 |      36
 2020-11-14 |      36
 2020-11-15 |      44
 2020-11-16 |      44
 2020-11-17 |     128
 2020-11-18 |      36
 2020-11-19 |      36
 2020-11-20 |      36
 2020-11-21 |      36
 2020-11-22 |      48
 2020-11-23 |      48
 2020-11-24 |      44
 2020-11-25 |      48
 2020-11-26 |      48
 2020-11-27 |      36
 2020-11-28 |      36
 2020-11-29 |     128
 2020-11-30 |      40
 2020-12-01 |      40
 2020-12-02 |      40
(32 rows)
```
