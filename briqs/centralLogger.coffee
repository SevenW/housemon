###
#   BRIQ: centralLogger
#   Version: 0.0.2
#
#   Based on BRIQ: rf12demo-readwrite v0.1.1 Author: lightbulb -at- laughlinez (dot) com
#   Author: SevenWatt
#           https://github.com/SevenW
#
#   License: MIT - see http://thedistractor.github.io/housemon/MIT-LICENSE.html
#   
#   About:
#   Communication with Battery backup centralLogger receiving RF12 and P1 data
#
###


state = require '../server/state'
_ = require 'underscore'
ss = require 'socketstream'
async = require 'async'
fs = require 'fs'


console.log 'tsLogger required by centralLogger'

tslogger = require './tsLogger'
console.log 'tsLogger required by centralLogger'

#tsl = new tslogger.factory
console.log tslogger.getLastTs()



exports.info =
  name: 'centralLogger'
  description: 'Read/Write Serial interface for a device (e.g Olimexino-STM32) running a CentralLogger.1 compatible sketches.'
  descriptionHtml: 'Read/Write interface for <b>CentralLogger.1</b> compatible devices.<br/>Additional settings are available once installed.<br/>For more information click the [about] link above.'
  author: 'SevenWatt'
  authorUrl: 'http://www.sevenwatt.com/'
  briqUrl: '/docs/#centralLogger.md'
  version: '0.0.1'
  inputs: [
    {
      name: 'Serial port'
      #default: '/dev/ttyAMA0' # TODO: list choices with serialport.list
      default: '/dev/CL1' # TODO: list choices with serialport.list
    }
    {    
      name: 'Baud Rate'
      default: 115200
    }
    {    
      name: 'Shell Version'
      default: null #supply a fixed version (don't go using version cmd which can cause loop on some CLI's)
    }
    
  ]
  connections:
    packages:
      'serialport': '*'
    results:
      'rf12.announce': 'event'
      'rf12.packet': 'event'
      'rf12.config': 'event'
      'rf12.other': 'event'
      'rf12.sendcomplete':'event'
      'rf12.version':'event'
      'rf12.write': 'event'
      'rf12.processWriteQ':'event'
  settings:
    initcmds:
      title: 'Initial commands sent on startup'
    writemasks:
      title: 'write mask(s) [see documentation link above]'
      default: null
    commands:
      title: 'Add/Override default CLI commands'
      default: null #'{"version":"v","config":"?"}' 
      
serialport = require 'serialport'
spList = serialport.list

class centralLogger extends serialport.SerialPort

  constructor: (@deviceInfo, params...) ->

    #define our instance variables
    @_registry      = null                                             #the registry this instance will be connected to 
    @_writerConfigs = null                                             #supported writer patterns
    @_nodeConfig    = {band:null,group:null,nodeid:null,collectmode:null,version:null}  #this nodes config data
    @_registered    = false                                            #have we registered our writers?
    @_writeable     = true                                             #can we support writes? (CentralLogger.1)
    @_cliCommands   = {"version":"v\r", "config":"c\r"}                #supported by CentralLogger.1
    @_debug         = true
    @_opening       = false
    @_opened        = false
    @_once          = true
    @_portAvailable = false
    @_portWatch     = 0
    @_options       = {baud:115200, version:null}                      #basic configuration options
  
    @_initCmdTimeOut= 1000                                              #delay from inited() call to issue of initial commands like config / version
    @_logEnabled    = false                                            #emit 'incoming' only when tsLogger is enabled
    @_writeQ        = []                                               #array of writes with associated delays

    @_gate          = false  #protect loop
    
    @_testFlag      = false  #for test use
    @_id = Date.now()
    console.log 'id: ', @_id

    #continue with constructor
   
    
    self = this
    console.log "MoreParams:", params if @_debug
    
    #params... this will allow specification of other properties e.g baud rates, for instance running JNu's (@ 38400)  
    #keep @deviceInfo seperate from @device as we may perform manipulation
    #     to the raw deviceInfo handle before we get the final device but this is briq specific (e.g file:/tmp/serialdata.txt)
    @device = @deviceInfo
    console.log "RFDemo #{@device} created" if @_debug
    
    # support some platform-specific shorthands
    switch process.platform
      when 'darwin' then port = @device.replace /^usb-/, '/dev/tty.usbserial-'
      when 'linux' then port = @device.replace /^tty/, '/dev/tty'
      else port = @device
      
    
    if params?[0]? #new baud rate
      try
          @_options.baud = parseInt(params[0])
      catch err
        console.log "Constructor Baud Param Error:#{err}"     
      finally
      
    if params?[1]? #supply specific version 
      try
          if !!params[1].trim()
            @_options.version = params[1]          
      catch err
        console.log "Constructor Version Param Error: #{err}"
      finally
      
      
    baud = @_options.baud
      
    console.info "Port:" + port + " Baud:" + baud if @_debug
    # construct the serial port object
    #super port,
    #  baudrate: baud
    #  flowcontrol: true
    #  buffersize: 200000
    #  parser: serialport.parsers.readline '\n'
    #  false
    super port,
      baudrate: 38400
      flowcontrol: true
      buffersize: 200000
      parser: serialport.parsers.readline '\n'
      disconnectedCallback: @disconnected
      false
    
    #open port if it exists
    @_portWatch = setInterval @findDevice, 2000

    #[part of the RF12Registry Interface]
    state.on 'RF12Registry.RegistryUp' , self.registryUp
    
    #[part of the RF12Registry Interface]
    state.on 'RF12Registry.RegistryDown', self.registryDown


    console.log "Constructor completes for #{@device} #{JSON.stringify @_options} with config:#{ JSON.stringify @_nodeConfig}" if @_debug
    
    
    
  #allows us to find out what we are 'after the fact'
  className : () =>
    return 'centralLogger'
    
  deviceName : () =>
    return @device

  setDebug : (flag) =>
    console.log "Briq setDebug = #{flag}"
    return @_debug = flag
  getDebug : () =>
    return @_debug 
  setConfig : (obj) =>
    
  setup: ()=>


    setTimeout =>
      
      console.log "Setup params start for:#{@device} #{JSON.stringify @_options} - config:#{ JSON.stringify @_nodeConfig }" if @_debug
    
      if !!@initcmds.trim()
        console.log "Sending Init sequence to #{@device}" if @_debug
        @write @initcmds

      unless @_options.version is null 
        @setVersion @device, @_options.version
        unless @_nodeConfig.version > 11
          try
            delete @_cliCommands.version
          catch err
          finally


      try
        if !!@commands.trim()
          #gui supplied some additional cli commands or overrides existing
          cmds = JSON.parse @commands
          @_cliCommands = _.extend @_cliCommands, cmds
          console.log "cliCommands now #{JSON.stringify(@_cliCommands)}" if @_debug
      catch err
        console.log "Parameter error:#{err} for :#{escape(@commands)} on #{@device}" if @_debug
      finally




          
      #get the CLI to emit our config string, then chain to version unless supplied
      if @_cliCommands.config?
        setTimeout =>
          @_testFlag = true
          console.log "rf12 config request for:#{@device}" if @_debug
          @write @_cliCommands.config
        , 800 #should be enough time for CLI to be ready after init?? TODO:move to a config setting
      
    , @_initCmdTimeOut #how long to wait before we start the init process.

    return true    

  #process the RegistryUp state event  
  #[part of the RF12Registry Interface]
  registryUp : (theRegistry) =>
  
    console.log "#{@deviceName()} got a Registry Event from Registry:#{theRegistry.instanceName()}"  if @_debug
    #we only register if we are not already registered, we can use setRegistry for others
    unless @_registry?
      console.log "#{@deviceName()} Registering with Registry:#{theRegistry.instanceName()}"  if @_debug
      @setRegistry( theRegistry )
      @setWriteable( @_writeable ) #force re-evaluation

    return @_registry  
      
  #process the registryDown state event    
  #[part of the RF12Registry Interface]
  registryDown: (theRegistry) =>
    #only interested if its our stored registry
    if @_registry == theRegistry
      console.log "Registry is down, attempting deregister" if @_debug
      @setRegistry(null)
      @setWriteable( false )

    return @_registry  #should be null
  
  #Are we able to process write requests?
  #[part of the RF12Registry Interface]
  setWriteable : (flag) =>
    @_writeable = flag
    if @_writeable #try and register writers
      if @_registry #we have a registry
      
        #if we have already registered writers we should deregister to clear them
        if @_registered
          @_registry.deregister this
          @_registered = false
          
        if not @_registered
          console.log "setWriteable calls @writers for: #{@device}" if @_debug
          @writers @writemasks , (err,result) => 
          
      else #we dont have registry but we are able to write 
        console.log "Request Registry to Report...by:#{@device}" if @_debug
        state.emit 'RF12Registry.Report' #if RF12Registry is listening it will respond with RF12Registry.RegistryUp      

    return @_writeable
    
    
  #allows us to supply an 'RF12Registry' to use as a registration service
  #[part of the RF12Registry Interface]
  setRegistry : (registry) =>
    console.log "Registry SET called by: #{@device}" if @_debug
    if (@_registry != null) and (@_registry != registry) #we are told to use a registry but its different to one we previously registered on, so deregister writers
      console.log "Need to DEREGISTER:", @device  if @_debug
      @_registry.deregister this
      @_registered = false
    
    @_registry = registry
    #we actually register for writes when a config is available which could be sometime later

    if @_registry == null
      @_registered = false
    
    return @_registry
    
  #used to Queue writes via the RF12Registry interface to abstract the input format
  #NB: I'd like to have used Write, but because we inherit serial then thats taken, and we need to proxy. (TODO: super.write....)
  #[part of the RF12Registry Interface]
  clientWrite : (buffer, delayNext, key) =>
    result = false
    console.log "Writing #{escape(buffer)} to our device #{@deviceName()}" if @_debug
    console.log "#{buffer}" if @_debug
    
    if Buffer.isBuffer(buffer) #unsupported in this version
      console.log "....it was a raw buffer so pass it directly"  if @_debug    

    #we use a Q, so next version is able to 'split' writes into multiple actions in one transaction
    #and also allows us to send long running requests with less chance of the next write messing us up.    
    @_writeQ.push {"buffer":buffer, "delayNext":delayNext,"key":key}
    state.emit "rf12.processWriteQ", @device #re-starts the message pump
    result = true

    #TODO: revert to callback as per v0.2.0
    return result     
    
  #processed any queued writes  
  #[part of the RF12Registry Interface]    
  processWriteQ : (thedevice) =>
    
    if @device != thedevice
      return null #was not our event
    
    #schedule timeout to process queue
    if not @_delayWriteQ #we dont need to wait.
    
      writeObj = @_writeQ.shift() #get oldest message
      console.log "Q Entry: #{JSON.stringify writeObj }" if @_debug
      try  
        if writeObj?.buffer? #do we have writeObj with buffer
          console.log "Writing to device #{@device} the buffer: #{escape(writeObj.buffer)}" if @_debug

          @write writeObj.buffer
          #TODO: add the band/group/node data as it may be useful for listeners
          state.emit 'rf12.write', {"datestamp":Date.now(),"device":@deviceName(),"data":writeObj.buffer}
          
          if writeObj?.delayNext?  #we will delay the next write by .delayNext ms
            @_delayWriteQ = true
            setTimeout =>
              @restartWriteQ()
            , writeObj.delayNext
          else
            #we use events so as not to recurse
            #pump the queue
            state.emit "rf12.processWriteQ", @device #re-starts the message pump
          
                    
              
      catch err
        #do nothing
      finally
        #do nothing
    
    
    return writeObj #may be null, in which case q is empty

  #[part of the RF12Registry Interface]
  restartWriteQ: () =>  
    @_delayWriteQ = false
    state.emit "rf12.processWriteQ", @device #re-starts the message pump
    

    
  #called when a device config is obtained to register write paths with the registry  
  #[part of the RF12Registry Interface]
  writers : ( writerConfigs, callback ) =>
    #writeconfigs are treated as single tokenized strings '{%b}/{%g}|{%1}' or if begin with '[', JSON objects i.e. '["{%b}/{%g}|{%1}", "{%b}/200|{%1}"]'
    #NOTE: JSON objects must be correctly formed
  
    #reset
    @_writerConfigs = [] #this will contain all the 'write' patterns we wish to support

  
    unless @_writeable
      console.log "Driver #{@deviceName()} is not currently write enabled" if @_debug
      return callback(null,false)

    if !writerConfigs.trim()
      console.log "No writeConfigs supplied" if @_debug
      return callback(null,false)
    
      
    console.log "RFDemo Writers: #{writerConfigs} for: #{@device}" if @_debug
    #when config arrives from device we merge to make patterns for registration
        
    #if first char is '[' we treat as JSON
    #otherwise we make into single dimension array
    #TODO: more elegant parse descision
    list = []
    if (writerConfigs.charAt(0) == '[') #or (writerConfigs.charAt(0) == '{')
      try
        list = JSON.parse( writerConfigs )
      catch err
        console.log "centralLogger: JSON format suggested, but unable to parse - err:#{err}" 
      finally
    else
      list.push writerConfigs
      
    
    for p,i in list 
      [bgpat, dpat...] = p.split '|' #split writestring from radio match
      bgpat = bgpat.replace /{%b}/g , @_nodeConfig.band #note: %B = 8, %b = 868
      bgpat = bgpat.replace /{%g}/g , @_nodeConfig.group
      bgpat = bgpat.replace /\//,'[.]' #turn / into dot
      #we now have a pattern that the 'registry' can regex to match for writes
      #this could be done in registry, but beneficial to keep a record in this object.

      if dpat?.length == 0 #never supplied anything after |
        dpat = ['{%1}'] #user did not supply write pattern, so we use default
      
      if dpat[0] == '{%1}' #translate into 'default' pattern for CentralLogger.1
        if @_nodeConfig.version == 9
          dpat[0] = "{%s}" #using older bytes,nodeid 's' syntax (no band switch)
        else
          dpat[0] = "{%B},{%g},{%i},{%h},{%s}>" #using new .10+ syntax that can switch bands etc
      
      
      #keep a record
      @_writerConfigs.push {"path":bgpat, "mask": dpat[0] }
    
    #register this instance for each 'write' pattern
    if @_registry
      self = this
      for p,i in @_writerConfigs
        @_registered = true
        @_registry.register self, p
        
        
    return callback(null,@_registered)    
  
  #does our CLI meet the requirement to support writes?  
  #[part of the RF12Registry Interface]
  isWriteable : () =>
    canWrite = @_nodeConfig.band? and @_nodeConfig.group? and @_nodeConfig.nodeid? and (@_nodeConfig.version? and (@_nodeConfig.version >= 1))
    console.log "isWriteable evaluates to #{canWrite} for:#{@device}" if @_debug
    return canWrite
  
        
  #[part of the RF12Registry Interface]
  setVersion : (thedevice, version) =>
    #reset gate
    @_gate = false
  
    console.log "I am #{@device} in setVersion" if @_debug
    try
      if parseFloat(version) 
        @_nodeConfig["version"] = parseFloat(version).toFixed(2)
        if @_nodeConfig["version"] >= 1
          console.log "RF12 is a writable interface for: #{@device}" if @_debug
          console.log "#{@device} calling setWriteable with #{ JSON.stringify(@_nodeConfig) }" if @_debug
          @setWriteable @isWriteable()         
    catch err
    
    finally      
      
    return @_nodeConfig["version"]
  
        
  #[part of the RF12Registry Interface]
  configure : (thedevice, data) =>
        console.log "event: rf12.config: from: #{thedevice} being reviewed by: #{@device}" if @_debug 
        #save last logged timestamp, because it will be updated by applying the date, before the tail starts.
        tailfrom = tslogger.getLastTs()
        if @device != thedevice #its not our event
          console.log "rf12.config rejected by: #{@device}" if @_debug
          return null

        if @_gate
          console.log "Gate has stopped event on : #{@device}"
          return #protect from loops       

        
        @_gate = true  
          
        console.log "#{@device} config data nodeid: #{@_nodeConfig.nodeid} group:#{@_nodeConfig.group} band:#{@_nodeConfig.band}" if @_debug

        #get the CLI to emit the version string unless we have been specifically told
        #what version we are to be
        unless @_nodeConfig.version?
          #but only if we have writers specified, as in the case 
          #of RF12Demo upto v10, does not support version cmd
          #and we dont need version if no writers specified
          
          if @_cliCommands.version? #TODO:check we dont need this validation any more?
            setTimeout =>
              @write @_cliCommands.version

            , 50
          else
            #no version cmd to use and no version specifically supplied           
            @setVersion(@device,'9')
            

        @setWriteable @isWriteable()
        
        console.log "going to set date"
        setTimeout =>
          @write Date.now()+'d'
        , 200 #allow 200ms for processing of verison command
        console.log "trying to switch to tail"
        console.log Date.now()
        console.log tailfrom
        console.log tslogger.getLastTs()
        if tailfrom >= 0
          setTimeout =>
            @write tailfrom+'t'
          , 300 #allow 300ms processing time for version and date setting
          @_logEnabled = true
        if tailfrom == -1
          setTimeout =>
            @write 1356998400000 +'t'
          , 300 #allow 300ms processing time for version and date setting
          @_logEnabled = true


  #we got what we think is a reply from a write?          
  #[part of the RF12Registry Interface]
  sendComplete : (device, bytes) =>
        if device != @device #we never sent this as its not our device
          return null

        console.log "Sendcomplete for: #{device} with #{bytes} bytes"  if @_debug

        return bytes
  
  openPort : =>
    self = this
    if @_opening then console.log 'openPort called while awaiting open event'
    else
      @on 'error', (err) =>
        console.log "@on error ", err if self._debug

      @on 'close', =>
        console.log "@on close Device closed..." + @device if self._debug
        @_logEnabled = false
        @_opened = false    
      
      @on 'open', =>
        @_opened = true
        console.log "@on open Port open..." + @device if self._debug

        @setup() #causes config data to be captured then chained to version 

        #TODO: These should be on the instance 
        info = {} #standard rf12demo format
        ainfo = {} #announcer info


        #does our instance have identity, if so we can listen for writes
        state.on 'rf12.sendcomplete', self.sendComplete    #message send confirmation
        state.on 'rf12.processWriteQ', self.processWriteQ  #check and pump messages
        
    
        @on 'data', (data) ->
          if data.length > 55
            console.log 'incoming data len = ', data.length, data
          data = data.slice(0, -1)  if data.slice(-1) is '\r'
          if data.length > 300 # ignore outrageously long lines of text
            console.log 'throw away lines > 300'
          else
            # broadcast raw event for data logging
            state.emit 'incoming', 'rf12demo', @device, data if @_logEnabled
            #console.log 'incoming', 'rf12demo', @device, data
            words = data.split ' '
            if words.length > 1 and (!isNaN words[0]) and words[1][0..1] is 'OK'
              # TODO: conversion to ints can fail if the serial data is garbled
              ts = parseInt words[0]
              info.id = (parseInt words[1][2..3], 16)  & 0x1F
              msg = words[1][2..]
              #console.log ts, info.id, msg
              hex = (parseInt msg[i..i+1],16 for a, i in msg by 2)
              info.buffer = new Buffer(parseInt msg[i..i+1],16 for a, i in msg by 2)
              #console.log info.buffer
              if info.id is 0
                # announcer packet: remember this info for each node id
                aid = words[1] & 0x1F
                ainfo[aid] ?= {}
                ainfo[aid].buffer = info.buffer
                state.emit 'rf12.announce', ainfo[aid]
              else
                # generate normal packet event, for decoders
                state.emit 'rf12.packet', info, ainfo[info.id]
            else if words.length > 1 and (!isNaN words[0]) and words[1][0..1] is 'CK'
              ts=Date.now()
              info.id = 31 #use this node id for clock readings centrallogger
              #words[1] = ts
              info.buffer = new Buffer 17
              info.buffer.writeUInt8 31, 0
              info.buffer.writeUInt32BE Math.floor(ts / 1000), 1
              info.buffer.writeUInt16BE ts % 1000, 5
              info.buffer.writeUInt32BE Math.floor(words[2] / 1000), 7
              info.buffer.writeUInt16BE words[2] % 1000, 11
              console.log words[2]
              console.log ts
              console.log words[2] - ts
              
              #info.buffer.writeUInt16BE words[2] - ts, 13
              state.emit 'rf12.packet', info, ainfo[info.id]
              console.log "ainfo[info.id]"
              console.log ainfo[info.id]
            else #something other than 'OK...'
              match = /^ -> (\d+) b/.exec data   #bytes sent?
              if match #we have results of a send from the mcu in the format ' -> x b' where x is bytes.
                 state.emit 'rf12.sendcomplete', @device, match[1]
              else
                # look for config lines of the form: A i1* g5 @ 868 MHz
                match = /^ [A-Z[\\\]\^_@] i(\d+)(\*)? g(\d+) @ (\d\d\d) MHz/.exec data
                if match
                  console.log "centralLogger:#{@device} config match:" , data #if self._debug
                  info.recvid = parseInt(match[1])
                  #added match[2] for collectmode
                  info.group = parseInt(match[3])
                  info.band = parseInt(match[4])
                  
                  @_nodeConfig["nodeid"] = match[1]
                  @_nodeConfig["collectmode"] = match[2]?
                  @_nodeConfig["group"] = match[3]
                  @_nodeConfig["band"] = match[4]

                  self.configure @device, data #see if we can successfully configure
                  state.emit "rf12.config" , @device, @_nodeConfig #tell world about config
                  console.info 'config', @device, @_nodeConfig if self._debug

                else
                  #look for a reply from a version command 'v'
                  match = /^\[CentralLogger\.([0-9]*\.[0-9]+|[0-9]+)]/i.exec data   
                  if match
                    self.setVersion @device, match.slice(1)
                    state.emit "rf12.version" , @device, @_nodeConfig["version"] #tell world about version 
                    console.info 'version', @device, @_nodeConfig["version"] if self._debug
                  else  
                    # unrecognized input, usually a "?" line
                    state.emit 'rf12.other', data
                    console.info 'other', @device, data if self._debug
                    
      console.log 'openPort: opening port now ...'
      @open()
      console.log 'open event?'
  
  #This gets called when first instantiated, and again every time we commit the optional parameters (as we are re-inited every time)
  inited: =>
    console.log @_id
  
    self = this
    #reset gate
    @_gate = false

    console.log "#{@device} is inited() with id:#{@_uniqueid} options:#{JSON.stringify @_options} config: #{JSON.stringify @_nodeConfig}" if @_debug
  
    if @_registry?
      #console.log "Closing Existing Registry..."
      @setRegistry null
  
    #try to open port as test for dis/reconnect USB
    #@open ->
    #  console.log 'open'
    
    console.log 'port opened is ', @_opened
    #inited is called everytime a gui parameter is changed (see debounce--replaced)    
    if @_opened #device is ready to recv
      console.log "Sending Startup for #{@device}..." if @_debug
      @setup() #causes config data to be captured then chained to version, if requested 
    #else
    #  @findDevice() #if port exists, it will be opened
    
    #@openPort()
      

  open : () =>
    self = this
    #avoid nested calls of open by openPort
    @_opening = true

    console.log "open() specialized from serialport called" if @_debug
    @on 'open', =>
      @_opened = true
      @_opening = false
      #console.log "@on open in open() Port open..." + @device if self._debug

    super (err) =>
      console.log err
    console.log '@_portWatch = ', @_portWatch
    console.log '@_id = ', @_id
    clearInterval @_portWatch
    @_portWatch = 0
    
  close : () =>
    self = this
    console.log "close() called" if @_debug
    super

    if @_registry?
      @_registry.deregister @

    @_registered = false
    @_writeable = false
    @_opened = false
    @_logEnabled = false
    @_portAvailable = false
    #reset gate
    @_gate = false

      
    #[part of the RF12Registry Interface]
    state.off 'RF12Registry.RegistryUp' , @registryUp
    state.off 'RF12Registry.RegistryDown', @registryDown
    state.off 'rf12.sendcomplete', @sendComplete
    state.off 'rf12.processWriteQ', @processWriteQ  
    
    console.log "#{@deviceName()} has closed (and should be deleted)." if @_debug
    @_portWatch = setInterval @findDevice, 2000
    
  disconnected : () =>
    self = this
    console.log "disconnected() called" if @_debug
    console.log "#{@deviceName()} got disconnected (and should be deleted)." if @_debug
    @close()
    
  findDevice : () =>
    @_portAvailable = false
    console.log 'findDevice'
    console.log typeof spList
    spList (err, ports) =>
      console.log ports
      for port in ports
        console.log port.comName
        console.log @device
        realdev = fs.realpathSync(@device);
        console.log realdev
        console.log typeof @deviceName()
        if (port.comName is @deviceName()) then @_portAvailable = true
        if (port.comName is realdev) then @_portAvailable = true
      console.log @_portAvailable, @_opened
      if @_portAvailable and not @_opened
        @openPort()

  destroy: -> 
    console.log "Destroy is calling close()" if @_debug
    @close()
        
exports.factory = centralLogger
