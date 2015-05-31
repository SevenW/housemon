module.exports =

  announcer: 31

  descriptions:
    ['CLTIME']

  CLTIME:
    tdiff:
      title: 'Time difference'
      unit: 'ms'

  feed: 'rf12.packet'

  decode: (raw, cb) ->
    hmTime_s = raw.readUInt32BE(1)
    hmTime_ms = raw.readUInt16BE(5)
    clTime_s = raw.readUInt32BE(7)
    clTime_ms = raw.readUInt16BE(11)
    hmTime = 1000 * hmTime_s + hmTime_ms
    clTime = 1000 * clTime_s + clTime_ms
    console.log  hmTime_s, hmTime_ms
    console.log  clTime_s, clTime_ms
    console.log  hmTime, clTime
    result =
      tag: 'CLTIME'
      tdiff: hmTime - clTime
    cb result
