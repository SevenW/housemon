module.exports =

  announcer: 112

  descriptions:
    atmp:
      title: 'Atmospheric pressure'
      unit: 'hPa'
      scale: 2
      min: 300
      max: 1100
    temp:
      title: 'Temperature'
      unit: '°C'
      scale: 1
      min: -40
      max: 85
    seq:
      title: 'Sequence number'

  feed: 'rf12.packet'

  decode: (raw, cb) ->
    console.log 'decode barometer data'
    cb
      seq: raw[1]
      #type: raw[2] #msg type 30 not used for processing
      temp: raw.readInt16LE(3, true)
      atmp: raw.readInt32LE(5, true)

