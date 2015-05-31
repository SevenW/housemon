module.exports =

  announcer: 111

  descriptions:
    humi:
      title: 'Relative humidity'
      unit: '%'
      min: 0
      max: 100
    light:
      title: 'Light intensity'
      min: 0
      max: 100
      factor: 100 / 255
      scale: 0
    moved:
      title: 'Motion'
      min: 0
      max: 1
    temp:
      title: 'Temperature'
      unit: '°C'
      scale: 1
      min: -50
      max: 50
    seq:
      title: 'Sequence number'

  feed: 'rf12.packet'

  decode: (raw, cb) ->
    console.log 'decode roomNode data'
    console.log raw.length
    console.log raw
    t = raw.readUInt16LE(4, true) & 0x3FF
    if raw.length > 2
      cb
        seq: raw[1]
        light: raw[2]
        humi: raw[3] >> 1
        moved: raw[3] & 1
        temp: if t < 0x200 then t else t - 0x400
        # temp from -512 (e.g. 51.2) --> +511 (e.g. 51.1) supported by roomNode sketch. NB 512 will be incorrectly reported!
    else
      console.log 'motion detect packet'

