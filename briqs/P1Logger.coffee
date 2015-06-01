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
p1fs = require 'fs'

console.log 'P1Logger main called'   
  
P1_LOGGER_PATH = './P1-logger'
p1fs.mkdir P1_LOGGER_PATH, ->

p1getDateString = (now) ->
  now.getUTCDate() + 100 * (now.getUTCMonth() + 1 + 100 * now.getUTCFullYear())

p1dateFilename = (now) ->
  # construct the date value as 8 digits
  y = now.getUTCFullYear()
  d = p1getDateString now
  # then massage it as a string to produce a file name
  path = "#{P1_LOGGER_PATH}/#{y}"
  p1fs.mkdirSync path  unless p1fs.existsSync path # TODO laziness: sync calls
  path + "/#{d}.txt"

    
class P1Logger
  
  p1logger: (type, device, data) ->
    @xcurrDate = 20100101 if @xcurrDate?
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
        logdate = p1getDateString tsDate
        # 1234567890123 /dev/ttyAMC0 OK035523000012
        log = "#{ts} #{device} #{msg}\n"
        console.log logdate
        console.log @xcurrDate
        if logdate != @xcurrDate
          @xcurrDate = logdate 
          p1fs.close @fd  if @fd?
          @fd = p1fs.openSync p1dateFilename(tsDate), 'a'
        #p1fs.write @fd, log
        
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
    @xcurrDate = 20100101
    state.on 'incoming', @p1logger
    console.log 'P1Logger constructor called'     
    @xcurrDate = 20100101
    console.log @xcurrDate
          
  destroy: ->
    state.off 'incoming', @p1logger
    p1fs.close @fd  if @fd?
    
exports.factory = P1Logger