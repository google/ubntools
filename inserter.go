// inserter loads gzipped json files into the database.
//
// File names must be of the pattern "ap-mca-dump-%d.json.gz", where %d is the unix timestamp.
// TODO: take timestamp from data?
//
// Example run:
//   ./inserter -dbconnect='host=/var/run/postgresql sslmode=disable' /path/to/*.gz
//
package main

// Copyright 2017 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import (
	"compress/gzip"
	"database/sql"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path"
	"regexp"
	"strconv"
	"time"

	_ "github.com/lib/pq"
)

var (
	dbConnect = flag.String("dbconnect", "", "DB connect string.")
)

// readFile reads compressed json file into string.
func readFile(fn string) (string, error) {
	f, err := os.Open(fn)
	if err != nil {
		return "", err
	}
	defer f.Close()
	fz, err := gzip.NewReader(f)
	defer fz.Close()
	d, err := ioutil.ReadAll(fz)
	if err != nil {
		return "", fmt.Errorf("reading input file: %v", err)
	}
	if err := fz.Close(); err != nil {
		return "", fmt.Errorf("failed to close gzipped stream: %v", err)
	}
	return string(d), nil
}

// loadFile loads a file into the database.
func loadFile(db *sql.DB, fn string) error {
	log.Printf("Loading %q...", fn)
	data, err := readFile(fn)
	if err != nil {
		return err
	}
	var ts time.Time
	{
		r := regexp.MustCompile(`^ap-mca-dump-(\d+)\.json\.gz$`)
		m := r.FindStringSubmatch(path.Base(fn))
		if len(m) != 2 {
			return fmt.Errorf("file name %q doesn't match: %v", fn, m)
		}
		i, err := strconv.ParseInt(m[1], 10, 64)
		if err != nil {
			return fmt.Errorf("file name %q doesn't match: %v", fn, err)
		}
		ts = time.Unix(i, 0)
	}

	if _, err := db.Exec("INSERT INTO apdata(id, ts, data) VALUES(gen_random_uuid(), $1,$2)", ts, data); err != nil {
		return fmt.Errorf("inserting data: %v", err)
	}
	return nil
}

func main() {
	flag.Parse()

	db, err := sql.Open("postgres", *dbConnect)
	if err != nil {
		log.Fatalf("DB connect: %v", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Fatalf("DB ping: %v", err)
	}
	for _, fn := range flag.Args() {
		if err := loadFile(db, fn); err != nil {
			log.Printf("Failed to load %q: %v", fn, err)
		}
	}
}
