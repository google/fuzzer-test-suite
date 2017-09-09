package main

import (
	"fmt"
	//	"io"
	"io/ioutil"
	"path"
	//        "strings"
	"encoding/csv"
	"os"
	"strconv"
)

func checkErr(e error) {
	if e != nil {
		fmt.Println("Poop! Error encountered:", e)
		os.Exit(1)
	}
}

// Removes non-directory elements of any []os.FileInfo
func onlyDirectories(potential_files []os.FileInfo) (out_ls []os.FileInfo) {
	for _, fd := range potential_files {
		if fd.IsDir() {
			out_ls = append(out_ls, fd)
		}
	}
	return
}

// Extend "records" matrix to have rows until time "desired_time"
// Return: Extended version of record
func extendRecordsToTime(records [][]string, desired_time int, record_cols int) [][]string {
	lenr := len(records)
	// records[1] stores cycle [1], as records[0] is column names
	for j := lenr; j < desired_time+1; j++ {
		records = append(records, make([]string, record_cols))
		records[j][0] = strconv.Itoa(j)
	}
	return records
}

// Handles the CSV Reader for a single trial, and updates records[][] accordingly. Returns the updated records
func handleTrialCSV(trial_reader *csv.Reader, records [][]string, column_name string, num_total_cols int, j int) [][]string {
	// Read whole CSV to an array
	experiment_records, err := trial_reader.ReadAll()
	checkErr(err)
	// Add the name of this new column to records[0]
	records[0] = append(records[0], column_name)

	final_time, err := strconv.Atoi(experiment_records[len(experiment_records)-1][0])
	checkErr(err)
	//If this test went longer than all of the others, so far
	if len(records) < final_time+1 {
		records = extendRecordsToTime(records, final_time, num_total_cols)
	}
	for _, row := range experiment_records {
		// row[0] is time, on the x-axis; row[1] is value, on the y-axis
		time_now, err := strconv.Atoi(row[0])
		checkErr(err)
		records[time_now][j+1] = row[1]
	}
	return records
}

func handleFengine(fengine os.FileInfo, bmark_path string, desired_report_fname string) [][]string {
	// Create matrix, to eventually become a CSV
	records := [][]string{{"time"}}

	// Enter sub-directories
	potential_trials, err := ioutil.ReadDir(path.Join(bmark_path, fengine.Name()))
	checkErr(err)
	trials := onlyDirectories(potential_trials)

	num_total_cols := len(trials) + 1
	for j, trial := range trials {
		// Create fds
		this_file, err := os.Open(path.Join(bmark_path, fengine.Name(), trial.Name(), desired_report_fname))
		checkErr(err)
		trial_reader := csv.NewReader(this_file)

		records = handleTrialCSV(trial_reader, records, fengine.Name()+"-"+trial.Name(), num_total_cols, j)
		this_file.Close()
	}

	this_fe_file, err := os.Create(path.Join(bmark_path, fengine.Name(), desired_report_fname))
	checkErr(err)
	this_fe_writer := csv.NewWriter(this_fe_file)
	this_fe_writer.WriteAll(records)
	this_fe_file.Close()
	return records
}

//func appendAllTrials(meta_records [][]string, records [][]string) [][]string {

// Identify the fastest trial column in records and add it to meta_records
func appendFastestTrial(meta_records [][]string, records [][]string) [][]string {
	// Initialized to false: track whether this trial has lasted a long time
	trials := make([]bool, len(records[0])-1)
	// Use int for faster comparisons
	finished_trials := len(trials)
	// Rows in Fastest Trial
	var rows_in_ft int
	var fastest_trial int

	// Find the fastest trial by working backwards, since data points are sometimes dropped
	for r := len(records) - 1; r > 0; r-- {
		for c := 1; c < len(records[r]); c++ {
			if !trials[c-1] && (len(records[r][c]) > 0) {
				trials[c-1] = true
				finished_trials--
				if finished_trials == 0 {
					fastest_trial = c
					rows_in_ft = r
					break
				}
			}
		}
		if finished_trials == 0 {
			break
		}
	}

	// Update meta_records
	if len(meta_records) < rows_in_ft+1 {
		meta_records = extendRecordsToTime(meta_records, rows_in_ft, len(meta_records[0]))
	}
	for j := 0; j <= rows_in_ft; j++ {
		meta_records[j] = append(meta_records[j], records[j][fastest_trial])
	}
	return meta_records
}

// Call handleFengine() for each fengine, then compose all fengine data into a single CSV for comparison
func handleBmark(bmark os.FileInfo, records_path string, desired_report_fname string) {
	bmark_records := [][]string{{"time"}}

	bmark_path = path.Join(records_path, bmark.Name())
	potential_fengines, err := ioutil.ReadDir(bmark_path)
	checkErr(err)
	// narrow potential_fengines to fengines so the indices of `range fengines` are useful
	fengines := onlyDirectories(potential_fengines)

	for _, fengine := range fengines {
		fengine_records := handleFengine(fengine, bmark_path, desired_report_fname)
		bmark_records = appendFastestTrial(bmark_records, fengine_records)
	}
	this_bm_file, err := os.Create(path.Join(bmark_path, desired_report_fname))
	checkErr(err)
	this_bm_writer := csv.NewWriter(this_bm_file)
	this_bm_writer.WriteAll(bmark_records)
	this_bm_file.Close()
}

// Enters all report subdirectories, from benchmark to fengine to trial;
// composes individual CSVs (only two columns) into larger CSVs
func composeAllNamed(desired_report_fname string) {
	reports_path := "./reports"
	bmarks, err := ioutil.ReadDir(reports_path)
	checkErr(err)
	for _, bmark := range bmarks {
		handleBmark(bmark, reports_path, desired_report_fname)
	}
}

func main() {
	composeAllNamed("coverage-graph.csv")
	composeAllNamed("corpus-size-graph.csv")
	composeAllNamed("corpus-elems-graph.csv")
	// createIFramesFor("setOfFrames.html")
	// <iframe width="960" height="500" src="benchmarkN/report.html" frameborder="0"></iframe>
}
