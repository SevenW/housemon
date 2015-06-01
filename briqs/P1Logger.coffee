exports.info =
  name: 'P1Logger'
  description: 'Log incoming P1 data to daily rotating text files'
  connections:
    feeds:
      'incoming': 'event'
    results:
      'p1logger': 'dir'
      'rf12.packet': 'event'
  downloads:
    '/p1logger': './P1-logger'

state = require '../server/state'
fs = require 'fs'

console.log 'P1Logger main called'   
  
P1_LOGGER_PATH = './P1-logger'
fs.mkdir P1_LOGGER_PATH, ->

getDateString = (now) ->
  now.getUTCDate() + 100 * (now.getUTCMonth() + 1 + 100 * now.getUTCFullYear())

dateFilename = (now) ->
  # construct the date value as 8 digits
  y = now.getUTCFullYear()
  d = getDateString now
  # then massage it as a string to produce a file name
  path = "#{P1_LOGGER_PATH}/#{y}"
  fs.mkdirSync path  unless fs.existsSync path # TODO laziness: sync calls
  path + "/PE#{d}.log"

yearFilename = (now, type) ->
  # construct the date value as 8 digits
  y = now.getUTCFullYear()
  # then massage it as a string to produce a file name
  path = "#{P1_LOGGER_PATH}/#{y}"
  fs.mkdirSync path  unless fs.existsSync path # TODO laziness: sync calls
  path + "/" + type + "#{y}.log"

    
#exports.factory = class
class P1Logger
  
  p1logger: (type, device, data) =>
    console.log "log from P1logger"
    console.log this
    console.log @currDate
    #@currDate = 20110101 if not @currDate?
    now = new Date
    msg = data
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
    #filter PD, PE, PG messages
    if msg[0..1] is 'PD' or msg[0..1] is 'PE' or msg[0..1] is 'PG'
    #if msg[0..1] is 'PE'
        #1433073560473 /dev/CL1 PE:30,0,1
        #1433073600491 /dev/CL1 PG:150531140000,5304340
        #1433026790149 /dev/CL1 PD:7911000,4138000,702000,1883000,150531000000,5302898,4944,0,6615,0,8636
        #console.log msg
        tsDate = new Date(ts)
        logdate = getDateString tsDate
        logyear = tsDate.getUTCFullYear()
        # 1234567890123 /dev/ttyAMC0 OK035523000012
        log = "#{ts} #{device} #{msg}\n"
        console.log logdate
        console.log @currDate
        if logdate != @currDate
          @currDate = logdate 
          fs.close @fd_pe  if @fd_pe?
          @fd_pe = fs.openSync dateFilename(tsDate), 'a'
        if logyear != @currYear
          @currYear = logyear 
          fs.close @fd_pd  if @fd_pd?
          @fd_pd = fs.openSync yearFilename(tsDate, "PD"), 'a'
          fs.close @fd_pg  if @fd_pg?
          @fd_pg = fs.openSync yearFilename(tsDate, "PG"), 'a'
        if msg[0..1] is 'PD'
          fs.write @fd_pd, log
        else if msg[0..1] is 'PE'
          fs.write @fd_pe, log
        else if msg[0..1] is 'PG'
          fs.write @fd_pg, log
        
        #publish event for processing by driver
        readings = msg[3..].split ','
        #console.log readings[0]
        
        info = {} #standard rf12demo format
        info.recvid = 1
        info.group = 178
        info.recvid = 868
        info.id = 30 #use this node id for P1 meter readings
        if msg[0..1] is 'PD'
          info.buffer = new Buffer 35
          info.buffer.writeUInt8 30, 0 #node id
          info.buffer.write msg[0..1], 1
          info.buffer.writeUInt32BE readings[0], 3
          info.buffer.writeUInt32BE readings[1], 7
          info.buffer.writeUInt32BE readings[2], 11
          info.buffer.writeUInt32BE readings[3], 15
          info.buffer.writeUInt32BE readings[6], 19
          info.buffer.writeUInt32BE readings[7], 23
          info.buffer.writeUInt32BE readings[8], 27
          info.buffer.writeUInt32BE readings[9], 31
        if msg[0..1] is 'PE'
          info.buffer = new Buffer 12
          info.buffer.writeUInt8 30, 0 #node id
          info.buffer.write msg[0..1], 1
          info.buffer.writeUInt32BE readings[0], 3
          info.buffer.writeUInt32BE readings[1], 7
          info.buffer.writeUInt8 readings[2], 11
        if msg[0..1] is 'PG'
          info.buffer = new Buffer 7
          info.buffer.writeUInt8 30, 0 #node id
          info.buffer.write msg[0..1], 1
          info.buffer.writeUInt32BE readings[1], 3
        state.emit 'rf12.packet', info, {} # ainfo[info.id]
        #console.log "P1logger emitted event"

  constructor: ->
    #@currDate = 20100101
    state.on 'incoming', @p1logger
    console.log 'P1Logger constructor called'     
    #@currDate = 20100102
    #console.log @currDate
    #console.log this
          
  destroy: ->
    state.off 'incoming', @p1logger
    fs.close @fd_pd  if @fd_pd?
    fs.close @fd_pe  if @fd_pe?
    fs.close @fd_pg  if @fd_pg?
    
exports.factory = P1Logger