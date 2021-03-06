package rfdata

import (
	"fmt"
	"os"
	"time"

	"github.com/jcw/flow"
	"github.com/jcw/jeebus/gadgets"
)

func init() {
	flow.Registry["Logger"] = func() flow.Circuitry { return &Logger{} }
}

// Logger picks up time stamps and generates log lines from text input.
// It then saves these lines in daily logfiles. Registers as "Logger".
type Logger struct {
	flow.Gadget
	Dir flow.Input
	In  flow.Input
	Out flow.Output //the full filename the logger has just cycled
	dir string
	fd  *os.File
}

// Start opening a logfile and generating timestamped entries.
func (w *Logger) Run() {
	if m, ok := <-w.Dir; ok {
		w.dir = m.(string)
		var last time.Time
		for m = range w.In {
			switch v := m.(type) {
			case time.Time:
				last = v
			case string:
				w.logOneLine(last, v, "-") // TODO: port not known
			}
		}
	}
}

func (w *Logger) logOneLine(asof time.Time, text, port string) {
	// figure out name of logfile based on UTC date, with daily rotation
	year, month, day := asof.Date()
	path := fmt.Sprintf("%s/%d", w.dir, year)
	err := os.MkdirAll(path, os.ModePerm)
	flow.Check(err)
	// e.g. "./logger/2014/20140122.txt"
	datePath := fmt.Sprintf("%s/%d.txt", path, (year*100+int(month))*100+day)

	if w.fd == nil || datePath != w.fd.Name() {
		if w.fd != nil {
			name := w.fd.Name()
			w.fd.Close()
			w.Out.Send(name) // report the closed file
		}
		mode := os.O_WRONLY | os.O_APPEND | os.O_CREATE
		fd, err := os.OpenFile(datePath, mode, os.ModePerm)
		flow.Check(err)
		w.fd = fd
	}
	// append a new log entry, here is an example of the format used:
	// 	L 01:02:03.537 usb-A40117UK OK 9 25 54 66 235 61 210 226 33 19
	hour, min, sec := asof.Clock()
	line := fmt.Sprintf("L %02d:%02d:%02d.%03d %s %s\n",
		hour, min, sec, jeebus.TimeToMs(asof)%1000, port, text)
	w.fd.WriteString(line)
}
