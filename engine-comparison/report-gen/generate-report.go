package main

import (
	"encoding/csv"
	"fmt"
	"io/ioutil"
	"os"
	"path"
	"strconv"
)

func checkErr(e error) {
	if e != nil {
		fmt.Println("Error: ", e)
		os.Exit(1)
	}
}

// Removes non-directory elements of any []os.FileInfo
func onlyDirectories(inLs []os.FileInfo) (outLs []os.FileInfo) {
	for _, fd := range inLs {
		if fd.IsDir() {
			outLs = append(outLs, fd)
		}
	}
	return
}

// Extend "records" matrix to have rows until time "desiredTime"
// Return: Extended version of record
func extendRecordsToTime(records [][]string, desiredTime int, recordCols int) [][]string {
	lenr := len(records)
	// records[1] stores cycle [1], as records[0] is column names
	for j := lenr; j < desiredTime+1; j++ {
		records = append(records, make([]string, recordCols))
		records[j][0] = strconv.Itoa(j)
	}
	return records
}

// Handles the CSV Reader for a single trial, and updates records[][] accordingly. Returns the updated records
func handleTrialCSV(trialReader *csv.Reader, records [][]string, colName string, totalCols int, trialNum int) [][]string {
	// Read whole CSV to an array
	trialRecords, err := trialReader.ReadAll()
	checkErr(err)
	// Add the name of this new column to records[0]
	records[0] = append(records[0], colName)

	finalTime, err := strconv.Atoi(trialRecords[len(trialRecords)-1][0])
	checkErr(err)
	//If this test went longer than all of the others, so far
	if len(records) < finalTime+1 {
		records = extendRecordsToTime(records, finalTime, totalCols)
	}
	for _, row := range trialRecords {
		// row[0] is time, on the x-axis; row[1] is value, on the y-axis
		time, err := strconv.Atoi(row[0])
		checkErr(err)
		records[time][trialNum+1] = row[1]
	}
	return records
}

func handleFEngine(fengine os.FileInfo, bmarkPath string, finalReportFName string) [][]string {
	// Create matrix, to eventually become a CSV
	records := [][]string{{"time"}}

	// Enter sub-directories
	fenginePath := path.Join(bmarkPath, fengine.Name())
	ls, err := ioutil.ReadDir(fenginePath)
	checkErr(err)
	trials := onlyDirectories(ls)

	totalCols := len(trials) + 1
	for j, trial := range trials {
		// Create fds
		trialCSV, err := os.Open(path.Join(fenginePath, trial.Name(), finalReportFName))
		checkErr(err)
		trialReader := csv.NewReader(trialCSV)

		records = handleTrialCSV(trialReader, records, fengine.Name()+"-"+trial.Name(), totalCols, j)
		trialCSV.Close()
	}

	fengineCSV, err := os.Create(path.Join(fenginePath, finalReportFName))
	checkErr(err)
	fengineWriter := csv.NewWriter(fengineCSV)
	fengineWriter.WriteAll(records)
	fengineCSV.Close()
	return records
}

func appendAllTrials(aggregateRecords [][]string, records [][]string) [][]string {
	if len(aggregateRecords) < len(records) {
		aggregateRecords = extendRecordsToTime(aggregateRecords, len(records)-1, len(aggregateRecords[0]))
	}
	for r, row := range records {
		aggregateRecords[r] = append(aggregateRecords[r], row[1:]...)
	}
	return aggregateRecords
}

// Identify the fastest trial column in records and add it to aggregateRecords
func appendFastestTrial(aggregateRecords [][]string, records [][]string) [][]string {
	// Initialized to false: track whether this trial has lasted a long time
	trials := make([]bool, len(records[0]))
	// Use int for faster comparisons
	finishedTrials := len(trials) - 1
	// Rows in Fastest Trial
	var rowsInFT int
	var fastestTrial int

	// Find the fastest trial by working backwards, since data points are sometimes dropped
	for r := len(records) - 1; r > 0; r-- {
		for c := 1; c < len(records[r]); c++ {
			if !trials[c] && (len(records[r][c]) > 0) {
				trials[c] = true
				finishedTrials--
				if finishedTrials == 0 {
					fastestTrial = c
					rowsInFT = r
					break
				}
			}
		}
		if finishedTrials == 0 {
			break
		}
	}

	// Update aggregateRecords
	if len(aggregateRecords) < rowsInFT+1 {
		aggregateRecords = extendRecordsToTime(aggregateRecords, rowsInFT, len(aggregateRecords[0]))
	}
	for j := 0; j <= rowsInFT; j++ {
		aggregateRecords[j] = append(aggregateRecords[j], records[j][fastestTrial])
	}
	return aggregateRecords
}

// Call handleFEngine() for each fengine, then compose all fengine data into a single CSV for comparison
func handleBmark(bmark os.FileInfo, recordsPath string, finalReportFName string) {
	bmarkRecords := [][]string{{"time"}}
	bmarkPath := path.Join(recordsPath, bmark.Name())
	ls, err := ioutil.ReadDir(bmarkPath)
	checkErr(err)
	fengines := onlyDirectories(ls)

	for _, fengine := range fengines {
		fengineRecords := handleFEngine(fengine, bmarkPath, finalReportFName)
		//bmarkRecords = appendFastestTrial(bmarkRecords, fengineRecords)
		bmarkRecords = appendAllTrials(bmarkRecords, fengineRecords)
	}
	bmCSV, err := os.Create(path.Join(bmarkPath, finalReportFName))
	checkErr(err)
	bmWriter := csv.NewWriter(bmCSV)
	bmWriter.WriteAll(bmarkRecords)
	bmCSV.Close()
}

// Enters all report subdirectories, from benchmark to fengine to trial;
// composes individual CSVs (only two columns) into larger CSVs
func composeAllNamed(finalReportFName string) {
	reportsPath := "./reports"
	bmarks, err := ioutil.ReadDir(reportsPath)
	checkErr(err)
	for _, bmark := range bmarks {
		handleBmark(bmark, reportsPath, finalReportFName)
	}
}

func main() {
	composeAllNamed("coverage-graph.csv")
	composeAllNamed("corpus-size-graph.csv")
	composeAllNamed("corpus-elems-graph.csv")
	// createIFramesFor("setOfFrames.html")
	// <iframe width="960" height="500" src="benchmarkN/report.html" frameborder="0"></iframe>
}
