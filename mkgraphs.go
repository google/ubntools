// mkgraphs renders graphs from database.
//
// Example run:
//   ./mkgraphs -dbconnect='host=/var/run/postgresql sslmode=disable'
package main

import (
	"bytes"
	"database/sql"
	"flag"
	"fmt"
	"log"
	"strings"
	"time"

	_ "github.com/lib/pq"
)

var (
	dbConnect = flag.String("dbconnect", "", "DB connect string.")
)

func main() {
	flag.Parse()
	if len(flag.Args()) > 0 {
		log.Fatalf("Extra args on cmdline: %q", flag.Args())
	}

	db, err := sql.Open("postgres", *dbConnect)
	if err != nil {
		log.Fatalf("DB connect: %v", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Fatalf("DB ping: %v", err)
	}

	rows, err := db.Query(`SELECT ts, ap, name, cu FROM view_radio_history ORDER BY ap, name, ts`)
	if err != nil {
		log.Fatalf("Failed to query: %v", err)
	}
	defer rows.Close()
	var last_ap, last_name string
	type dp struct {
		ts time.Time
		cu int64
	}
	var data []dp
	var datas []string
	var metadatas []string

	metadatas = append(metadatas, `
set terminal pngcairo size 1280,800
set output 'foo.png'
set xdata time
set ylabel "Channel utilization %"
set xtics rotate
set timefmt "%s"
set format x "%Y-%m-%d %H:%M"
plot `)
	var plots []string

	output := func(ap, name string) {
		if len(data) > 0 {
			plots = append(plots, fmt.Sprintf(`$data_%d using 1:2 w l title '%s %s'`, len(datas), ap, name))
			var buf bytes.Buffer
			for _, d := range data {
				fmt.Fprintf(&buf, "%d %d\n", d.ts.Unix(), d.cu)
			}
			data = nil
			datas = append(datas, fmt.Sprintf("$data_%d << EOD\n%sEOD", len(datas), buf.String()))
		}
	}
	for rows.Next() {
		var ap, name string
		var cu int64
		var ts time.Time
		if err := rows.Scan(&ts, &ap, &name, &cu); err != nil {
			log.Fatalf("Failed to scan: %v", err)
		}
		if last_ap != ap || last_name != name {
			output(last_ap, last_name)
			last_ap = ap
			last_name = name
		}
		data = append(data, dp{ts: ts, cu: cu})
	}
	output(last_ap, last_name)
	fmt.Printf("%s\n%s%s\n", strings.Join(datas, "\n"), strings.Join(metadatas, "\n"), strings.Join(plots, ","))
}
