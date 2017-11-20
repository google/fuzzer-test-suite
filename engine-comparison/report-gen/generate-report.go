package main

import (
	"encoding/csv"
	"fmt"
	"io/ioutil"
	"os"
	"path"
	"strconv"
	"strings"
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

// Strips the "-trial-X" suffix from a column name
func stripTrial(colName string) string {
	splitStrings := strings.Split(colName, "-")
	return strings.Join(splitStrings[:len(splitStrings)-2], "-")
}

// Returns the average of a slice of numbers. Input and output are strings.
func stringNumAverage(nums []string) string {
	sum := 0
	count := 0
	for _, numStr := range nums {
		if numStr != "" {
			num, err := strconv.Atoi(numStr)
			checkErr(err)
			sum += num
			count++
		}
	}
	if count == 0 {
		return ""
	}
	return strconv.Itoa(sum / count)
}

func max(nums []int) int {
	myMax := nums[0]
	for i := 1; i < len(nums); i++ {
		if nums[i] > myMax {
			myMax = nums[i]
		}
	}
	return myMax
}

// Returns the max of a slice of numbers. Input and output are strings.
func stringNumMax(nums []string) string {
	intNums := []int{}
	for _, numStr := range nums {
		if numStr != "" {
			num, err := strconv.Atoi(numStr)
			checkErr(err)
			intNums = append(intNums, num)
		}
	}
	if len(intNums) == 0 {
		return ""
	}
	return strconv.Itoa(max(intNums))
}

// Copies previous row's data for any skipped trials.  Does not fill empty cells
// at the end of the table.
func fillEmptyCells(records [][]string) [][]string {
	// Determine where to stop filling data for each column.
	stoppingPoints := make([]int, len(records[0]))
	for row := len(records) - 1; row > 0; row-- {
		for col := 1; col < len(records[row]); col++ {
			if stoppingPoints[col] == 0 && records[row][col] != "" {
				stoppingPoints[col] = row
			}
		}
	}

	// Fill empty cells occurring before the stopping points
	finalStoppingPoint := max(stoppingPoints)
	for row := 1; row < finalStoppingPoint; row++ {
		for col := 1; col < len(records[row]); col++ {
			if row < stoppingPoints[col] && records[row][col] == "" {
				if row == 1 {
					records[row][col] = strconv.Itoa(0)
				} else {
					records[row][col] = records[row-1][col]
				}
			}
		}
	}
	return records
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
	records = extendRecordsToTime(records, len(aggregateRecords)-1, len(records[0]))
	aggregateRecords = extendRecordsToTime(aggregateRecords, len(records)-1, len(aggregateRecords[0]))
	for r, row := range records {
		aggregateRecords[r] = append(aggregateRecords[r], row[1:]...)
	}
	return aggregateRecords
}

func appendAverages(aggregateRecords [][]string, records [][]string) [][]string {
	records = extendRecordsToTime(records, len(aggregateRecords)-1, len(records[0]))
	aggregateRecords = extendRecordsToTime(aggregateRecords, len(records)-1, len(aggregateRecords[0]))

	// To calculate averages, we first need to interpolate missing data.
	records = fillEmptyCells(records)

	colName := stripTrial(records[0][1]) + "-avg"
	aggregateRecords[0] = append(aggregateRecords[0], colName)
	for i := 1; i < len(records); i++ {
		avg := stringNumAverage(records[i][1:])
		aggregateRecords[i] = append(aggregateRecords[i], avg)
	}
	return aggregateRecords
}

func appendMaxes(aggregateRecords [][]string, records [][]string) [][]string {
	records = extendRecordsToTime(records, len(aggregateRecords)-1, len(records[0]))
	aggregateRecords = extendRecordsToTime(aggregateRecords, len(records)-1, len(aggregateRecords[0]))

	// To calculate maxes, we first need to interpolate missing data.
	records = fillEmptyCells(records)

	colName := stripTrial(records[0][1]) + "-max"
	aggregateRecords[0] = append(aggregateRecords[0], colName)
	for i := 1; i < len(records); i++ {
		max := stringNumMax(records[i][1:])
		aggregateRecords[i] = append(aggregateRecords[i], max)
	}
	return aggregateRecords
}

// Call handleFEngine() for each fengine, then compose all fengine data into a single CSV for comparison
func handleBmark(bmark os.FileInfo, recordsPath string, finalReportFName string) {
	bmarkRecords := [][]string{{"time"}}
	bmarkAvgRecords := [][]string{{"time"}}
	bmarkMaxRecords := [][]string{{"time"}}
	bmarkPath := path.Join(recordsPath, bmark.Name())
	ls, err := ioutil.ReadDir(bmarkPath)
	checkErr(err)
	fengines := onlyDirectories(ls)

	for _, fengine := range fengines {
		fengineRecords := handleFEngine(fengine, bmarkPath, finalReportFName)
		bmarkRecords = appendAllTrials(bmarkRecords, fengineRecords)
		bmarkAvgRecords = appendAverages(bmarkAvgRecords, fengineRecords)
		bmarkMaxRecords = appendMaxes(bmarkMaxRecords, fengineRecords)
	}
	bmCSV, err := os.Create(path.Join(bmarkPath, finalReportFName))
	checkErr(err)
	bmWriter := csv.NewWriter(bmCSV)
	bmWriter.WriteAll(bmarkRecords)
	bmCSV.Close()
	bmAvgCSV, err := os.Create(path.Join(bmarkPath, "avg-"+finalReportFName))
	checkErr(err)
	bmWriter = csv.NewWriter(bmAvgCSV)
	bmWriter.WriteAll(bmarkAvgRecords)
	bmAvgCSV.Close()
	bmMaxCSV, err := os.Create(path.Join(bmarkPath, "max-"+finalReportFName))
	checkErr(err)
	bmWriter = csv.NewWriter(bmMaxCSV)
	bmWriter.WriteAll(bmarkMaxRecords)
	bmMaxCSV.Close()
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
