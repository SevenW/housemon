exports.info =
  name: 'tsLogger'
  description: 'Log incoming data to daily rotating text files'
  connections:
    feeds:
      'incoming': 'event'
    results:
      'logger': 'dir'
  downloads:
    '/logger': './ts-logger'

state = require '../server/state'
fs = require 'fs'
mqtt = require 'mqtt'

console.log 'tsLogger main called'   
  
last_ts = -1
LOGGER_PATH = './ts-logger'
fs.mkdir LOGGER_PATH, ->

#prepare mqtt connection
sevenw = mqtt.createClient(41883, "192.168.0.125")

getDateString = (now) ->
  now.getUTCDate() + 100 * (now.getUTCMonth() + 1 + 100 * now.getUTCFullYear())

dateFilename = (now) ->
  # construct the date value as 8 digits
  y = now.getUTCFullYear()
  d = getDateString now
  # then massage it as a string to produce a file name
  path = "#{LOGGER_PATH}/#{y}"
  fs.mkdirSync path  unless fs.existsSync path # TODO laziness: sync calls
  path + "/#{d}.txt"



  
tailFile = (fn) ->
  #find the last line to read the time stamp
  size = (fs.statSync fn).size
  frompos = Math.max(0, size-500)
  len = size - frompos
  fd = fs.openSync fn, 'r'
  data = new Buffer(len)
  nbytes = fs.readSync fd, data, 0, len, frompos
  fs.closeSync fd
  #search data for ts
  lines = (data.toString()).split "\n"
  ts = 0
  i = lines.length
  #for line in lines by -1 when ts is 0
  while (ts is 0) and (--i >= 0)
    line = lines[i]
    if /^[0-9]{13} /.test line
      ts = parseInt line[0..12]
  console.log 'tailFile: ts: ', ts
  ts
  
  
findLast = ->
  d = new  Date()
  y = d.getUTCFullYear()
  yl = if y<=2011 then y else 2011
  #start today and search back per day to find the latest log
  ts = 0
  while ts is 0
    path = "#{LOGGER_PATH}/#{y}"
    if fs.existsSync path
      fn = path + "/#{getDateString d}.txt"
      console.log 'findLast: ', fn
      ts = tailFile fn if fs.existsSync fn
    else
      console.log 'findLast: year path does NOT exists', "#{LOGGER_PATH}/#{y}"
      #go to januari first of this year
      d.setDate(1)
      d.setMonth(0)
    #decrement a day, and update year
    d = new Date(d.getTime() - 86400000);
    y = d.getUTCFullYear()
    if y < yl then ts = -1 #step out, we did not find any timestamp
  ts
    
getLastTs = ->
  last_ts    

exports.getLastTs = getLastTs

#timeString = (now) ->
#  # first construct the value as 10 digits
#  digits = now.getUTCMilliseconds() + 1000 *
#          (now.getUTCSeconds() + 100 *
#          (now.getUTCMinutes() + 100 *
#          (now.getUTCHours() + 100)))
#  # then massage it as a string to get the punctuation right
#  digits.toString().replace /.(..)(..)(..)(...)/, '$1:$2:$3.$4'

exports.factory = class
#class tsLogger
  
  logger: (type, device, data) =>
    now = new Date
    console.log "log from ts-logger"
    console.log this
    # parse log string and add timestamp when missing
    if /^[0-9]{13} /.test data
      ts = parseInt data[0..12]
      msg = data[14..]
    else if /^[0-9]{10} /.test data
      ts = parseInt data[0..9]+'000'
      msg = data[11..]
    else
      ts = Date.now()
      msg = data
    tsDate = new Date(ts)
    logdate = getDateString tsDate
    # 1234567890123 /dev/ttyAMC0 OK035523000012
    log = "#{ts} #{device} #{msg}\n"
    if logdate != @currDate
      @currDate = logdate 
      fs.close @fd  if @fd?
      @fd = fs.openSync dateFilename(tsDate), 'a'
    last_ts = ts
    fs.write @fd, log
    sevenw.publish "centrallogger/state", "#{ts} #{device} #{msg}"   

  constructor: ->
    last_ts = -1
    last_ts = findLast()
    console.log 'tsLogger last_ts ', last_ts
    state.on 'incoming', @logger
    console.log 'tsLogger constructor called'     
          
  destroy: ->
    state.off 'incoming', @logger
    fs.close @fd  if @fd?
    
#exports.factory = tsLogger